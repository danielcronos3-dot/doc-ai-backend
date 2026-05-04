import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';

const endpointChat = "/chat";

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class SavedReport {
  final String nombre;
  final DateTime fecha;
  final List<Map<String, dynamic>> tabla;
  final List<Map<String, dynamic>> resumen;
  final String tipoGrafica;

  SavedReport({
    required this.nombre,
    required this.fecha,
    required this.tabla,
    required this.resumen,
    required this.tipoGrafica,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF10172A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFB84DFF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6D5DF6),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          themeMode: mode,
          home: const LoginScreen(),
        );
      },
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> loginAnonimo(BuildContext context) async {
  try {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(user: userCredential.user!),
      ),
    );
  } catch (e) {
    print("ERROR LOGIN ANONIMO: $e");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("No se pudo entrar como invitado: $e"),
      ),
    );
  }
}


  Future<void> loginGoogle(BuildContext context) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(user: userCredential.user!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF10172A) : const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text("DashIA")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => loginGoogle(context),
                icon: const Icon(Icons.login),
                label: const Text("Iniciar sesión con Google"),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => loginAnonimo(context),
                icon: const Icon(Icons.person_outline),
                label: const Text("Entrar como invitado"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String baseUrl = "https://doc-ai-backend-0ryt.onrender.com";

  List<Map<String, dynamic>> tabla = [];
  List<Map<String, dynamic>> resumen = [];
  List<SavedReport> historial = [];

  String filtroCliente = "Todos";
  String filtroMes = "Todos";
  String tipoGrafica = "barras";

  bool comparacionActiva = false;
  String tipoComparacion = "cliente";
  String comparacionA = "N/A";
  String comparacionB = "N/A";

  String estadoArchivo = "";
  String respuestaIA = "";
  bool cargando = false;

  final preguntaController = TextEditingController();
  final nombreReporteController = TextEditingController(text: "Reporte");
  String get userId => widget.user.uid;

Map<String, String> get jsonHeaders => {
      "Content-Type": "application/json",
      "X-User-Id": userId,
    };

Map<String, String> get userHeaders => {
      "X-User-Id": userId,
    };


  @override
  void dispose() {
    preguntaController.dispose();
    nombreReporteController.dispose();
    super.dispose();
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get pageTop => isDark ? const Color(0xFF10172A) : const Color(0xFFF5F7FB);
  Color get pageBottom => isDark ? const Color(0xFF1E2A52) : const Color(0xFFE8EDFF);
  Color get panelColor => isDark ? const Color(0xFF151827) : Colors.white;
  Color get panelText => isDark ? Colors.white : const Color(0xFF111827);
  Color get softText => isDark ? Colors.white70 : Colors.black54;

  double _monto(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value.toString().replaceAll("\$", "").replaceAll(",", ""),
        ) ??
        0;
  }

  List<Map<String, dynamic>> get tablaFiltrada {
    return tabla.where((item) {
      final cliente = (item["cliente"] ?? "N/A").toString();
      final mes = (item["mes"] ?? "N/A").toString();

      final coincideCliente =
          filtroCliente == "Todos" || cliente == filtroCliente;
      final coincideMes = filtroMes == "Todos" || mes == filtroMes;

      return coincideCliente && coincideMes;
    }).toList();
  }

  List<Map<String, dynamic>> get resumenFiltrado {
    final acumulado = <String, double>{};

    for (final item in tablaFiltrada) {
      final cliente = (item["cliente"] ?? "N/A").toString();
      acumulado[cliente] = (acumulado[cliente] ?? 0) + _monto(item["monto"]);
    }

    return acumulado.entries
        .map((e) => {"cliente": e.key, "total": e.value})
        .toList();
  }

  List<String> get clientesDisponibles {
    final clientes = tabla
        .map((e) => (e["cliente"] ?? "N/A").toString())
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    clientes.sort();
    return ["Todos", ...clientes];
  }

  List<String> get mesesDisponibles {
    final meses = tabla
        .map((e) => (e["mes"] ?? "N/A").toString())
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    meses.sort();
    return ["Todos", ...meses];
  }

  Future<void> subirArchivos(List<PlatformFile> files) async {
  setState(() {
    cargando = true;
    estadoArchivo = "Subiendo archivos...";
  });

  try {
    print("ENTRÉ A subirArchivos");
    print("Enviando ${files.length} archivos");

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload'),
    );

    request.headers.addAll(userHeaders);

    for (final file in files) {
      if (file.path != null) {
        print("Subiendo por path: ${file.path}");

        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path!,
            filename: file.name,
          ),
        );
      } else if (file.bytes != null) {
        print("Subiendo por bytes: ${file.name}");

        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else {
        print("Archivo sin path ni bytes: ${file.name}");
      }
    }

    if (request.files.isEmpty) {
      setState(() {
        estadoArchivo = "No se pudo leer el archivo seleccionado";
        cargando = false;
      });
      return;
    }
    print("USER ID UPLOAD: $userId");
    print("UPLOAD URL: $baseUrl/upload");


    final response = await request.send().timeout(
          const Duration(seconds: 180),
        );

    final respStr = await response.stream.bytesToString();

    print("UPLOAD STATUS: ${response.statusCode}");
    print("UPLOAD BODY: $respStr");

    if (response.statusCode == 200) {
      final data = jsonDecode(respStr);

      setState(() {
        estadoArchivo =
            "Archivos en memoria: ${data["archivos_en_memoria"] ?? files.length}";
      });
    } else {
      setState(() {
        estadoArchivo = "Error al subir: ${response.statusCode}";
      });
    }
  } catch (e) {
    print("ERROR UPLOAD FLUTTER: $e");

    setState(() {
      estadoArchivo = "Error de conexión al subir";
    });
  }

  setState(() => cargando = false);
}



  Future<void> analizarDocumento() async {
  setState(() {
    cargando = true;
    estadoArchivo = "Analizando...";
  });

  final url = "$baseUrl/analizar";
  print("ANALIZANDO URL: $url");
  print("USER ID ANALIZAR: $userId");

  try {
    final response = await http
        .post(
          Uri.parse(url),
          headers: jsonHeaders,
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 240));

    print("ANALIZAR STATUS: ${response.statusCode}");
    print("ANALIZAR BODY: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        tabla = List<Map<String, dynamic>>.from(data["data"] ?? []);
        resumen = List<Map<String, dynamic>>.from(data["resumen"] ?? []);
        filtroCliente = "Todos";
        filtroMes = "Todos";
        comparacionActiva = false;

        if (tabla.isEmpty) {
          estadoArchivo = data["mensaje"] ?? "No se encontraron datos";
        } else {
          estadoArchivo = "Dashboard actualizado";
        }
      });
    } else {
      setState(() {
        estadoArchivo = "Error del servidor: ${response.statusCode}";
      });
    }
  } catch (e) {
    print("ERROR ANALIZAR FLUTTER: $e");

    setState(() {
      estadoArchivo = "Error de conexión al analizar";
    });
  }

  setState(() => cargando = false);
}


  Future<void> seleccionarArchivo() async {
  print("ABRIENDO FILE PICKER");

  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: false,
    type: FileType.custom,
    allowedExtensions: [
      'pdf', 'png', 'jpg', 'jpeg', 'webp', 'bmp',
      'xlsx', 'xls', 'csv', 'sql', 'txt', 'json', 'xml', 'html', 'md',
    ],
  );

  print("FILE PICKER TERMINO");

  if (result == null || result.files.isEmpty) {
    print("SE CANCELÓ EL PICKER");
    setState(() => estadoArchivo = "Selección cancelada");
    return;
  }

  print("ARCHIVOS SELECCIONADOS: ${result.files.length}");

  for (final file in result.files) {
    print("Archivo: ${file.name}");
    print("Path: ${file.path}");
    print("Bytes: ${file.bytes?.length}");
  }

  await subirArchivos(result.files);
  await analizarDocumento();
}


  void aplicarComandoDashboard(String texto) {
    final match = RegExp(r"\{[\s\S]*\}").firstMatch(texto);
    if (match == null) return;

    try {
      final command = jsonDecode(match.group(0)!);
      if (command is! Map) return;

      setState(() {
        final grafica = command["tipoGrafica"]?.toString();
        final cliente = command["filtroCliente"]?.toString();
        final mes = command["filtroMes"]?.toString();

        if (grafica != null &&
            ["barras", "pastel", "dona", "lineas", "dispersion", "heatmap", "combinado"]
                .contains(grafica)) {
          tipoGrafica = grafica;
        }

        if (cliente != null && clientesDisponibles.contains(cliente)) {
          filtroCliente = cliente;
        }

        if (mes != null && mesesDisponibles.contains(mes)) {
          filtroMes = mes;
        }
      });
    } catch (_) {}
  }

  Future<void> preguntarIA() async {
    final pregunta = preguntaController.text.trim();
    if (pregunta.isEmpty) return;

    setState(() {
      cargando = true;
      respuestaIA = "Pensando...";
    });

    try {
      final preguntaConControl = """
$pregunta

Si el usuario pide cambiar el dashboard, al final responde también un JSON válido con esta forma:
{"tipoGrafica":"barras|pastel|dona|lineas|dispersion|heatmap|combinado","filtroCliente":"Todos","filtroMes":"Todos"}
Solo incluye valores existentes si los conoces.
""";

      final response = await http
          .post(
            Uri.parse("$baseUrl$endpointChat"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"mensaje": preguntaConControl}),
          )
          .timeout(const Duration(seconds: 240));
      print("ANALIZAR STATUS: ${response.statusCode}");
      print("ANALIZAR BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final respuesta = data["respuesta"] ?? "Sin respuesta";

        setState(() => respuestaIA = respuesta);
        aplicarComandoDashboard(respuesta.toString());
      } else {
        setState(() => respuestaIA = "Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => respuestaIA = "Error conectando con la IA");
    }

    setState(() => cargando = false);
  }

  Future<void> limpiarDatos() async {
    setState(() {
      cargando = true;
      estadoArchivo = "Limpiando datos...";
    });

    try {
      await http.post(Uri.parse("$baseUrl/reset")).timeout(const Duration(seconds: 30));
    } catch (_) {}

    setState(() {
      tabla = [];
      resumen = [];
      filtroCliente = "Todos";
      filtroMes = "Todos";
      respuestaIA = "";
      estadoArchivo = "Datos eliminados";
      cargando = false;
    });
  }

  Future<void> descargardashboard() async {
    final response = await http.get(
      Uri.parse("$baseUrl/descargar-dashboard?tipo=$tipoGrafica"),
    );

    if (response.statusCode == 200) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/dashboard.png");
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    }
  }

  Future<void> descargarexcel() async {
    final response = await http.get(Uri.parse("$baseUrl/descargar-excel"));

    if (response.statusCode == 200) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/reporte.xlsx");
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    }
  }

  void guardarDashboard() {
    if (tabla.isEmpty) return;

    final nombre = nombreReporteController.text.trim().isEmpty
        ? "Reporte ${historial.length + 1}"
        : nombreReporteController.text.trim();

    setState(() {
      historial.insert(
        0,
        SavedReport(
          nombre: nombre,
          fecha: DateTime.now(),
          tabla: List<Map<String, dynamic>>.from(tabla),
          resumen: List<Map<String, dynamic>>.from(resumen),
          tipoGrafica: tipoGrafica,
        ),
      );
      estadoArchivo = "Dashboard guardado";
    });
  }

  void cargarReporte(SavedReport reporte) {
    setState(() {
      tabla = List<Map<String, dynamic>>.from(reporte.tabla);
      resumen = List<Map<String, dynamic>>.from(reporte.resumen);
      tipoGrafica = reporte.tipoGrafica;
      filtroCliente = "Todos";
      filtroMes = "Todos";
      estadoArchivo = "Reporte cargado: ${reporte.nombre}";
    });
  }

  void cambiarTema(ThemeMode mode) {
    themeModeNotifier.value = mode;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageTop,
      appBar: AppBar(
        backgroundColor: panelColor,
        foregroundColor: panelText,
        title: Text(
          "Doc AI - ${widget.user.email ?? "Invitado"}",
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6),
            onSelected: cambiarTema,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text("Sistema")),
              PopupMenuItem(value: ThemeMode.dark, child: Text("Oscuro")),
              PopupMenuItem(value: ThemeMode.light, child: Text("Claro")),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [pageTop, pageBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              _mainButton("Subir archivo(s)", Icons.upload_file, seleccionarArchivo),
              const SizedBox(height: 10),
              _mainButton("Generar Dashboard", Icons.auto_graph, analizarDocumento),
              const SizedBox(height: 10),
              _mainButton("Descargar Dashboard", Icons.bar_chart, descargardashboard),
              const SizedBox(height: 10),
              _mainButton("Descargar Excel", Icons.download, descargarexcel),
              const SizedBox(height: 10),
              _dangerButton("Limpiar datos", Icons.refresh, limpiarDatos),
              const SizedBox(height: 10),
              Text(estadoArchivo, style: TextStyle(color: softText)),
              if (cargando) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 20),
              if (tabla.isNotEmpty) ...[
                buildSavePanel(),
                const SizedBox(height: 20),
                buildFiltros(),
                const SizedBox(height: 20),
                buildComparisonPanel(),
                const SizedBox(height: 20),
                buildTipoGrafica(),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: buildKPIs(),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: buildTablaDetalle(),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.03, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    key: ValueKey(
                      "$tipoGrafica-$filtroCliente-$filtroMes-$comparacionActiva-$comparacionA-$comparacionB",
                    ),
                    child: comparacionActiva
                        ? buildComparisonChart()
                        : buildDashboardChart(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              buildHistoryPanel(),
              const SizedBox(height: 20),
              buildChatCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFB84DFF),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: cargando ? null : onPressed,
      icon: Icon(icon),
      label: Text(text),
    );
  }

  Widget _dangerButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B6B),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: cargando ? null : onPressed,
      icon: Icon(icon),
      label: Text(text),
    );
  }

  Widget buildSavePanel() {
    return Card(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: nombreReporteController,
              style: TextStyle(color: panelText),
              decoration: const InputDecoration(labelText: "Nombre del reporte"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: guardarDashboard,
              icon: const Icon(Icons.save),
              label: const Text("Guardar dashboard"),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHistoryPanel() {
    if (historial.isEmpty) return const SizedBox.shrink();

    return Card(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Historial", style: TextStyle(color: panelText, fontSize: 16)),
            const SizedBox(height: 10),
            ...historial.take(5).map((reporte) {
              return ListTile(
                dense: true,
                title: Text(reporte.nombre, style: TextStyle(color: panelText)),
                subtitle: Text(
                  reporte.fecha.toString().substring(0, 16),
                  style: TextStyle(color: softText),
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => cargarReporte(reporte),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget buildTipoGrafica() {
    final tipos = {
      "barras": "Barras",
      "pastel": "Pastel",
      "dona": "Dona",
      "lineas": "Líneas",
      "dispersion": "Dispersión",
      "heatmap": "Heatmap",
      "combinado": "Combinado",
    };

    return _dropdown(
      value: tipoGrafica,
      items: tipos.keys.toList(),
      labels: tipos,
      onChanged: (value) => setState(() => tipoGrafica = value),
    );
  }

  Widget buildFiltros() {
    return Column(
      children: [
        _dropdown(
          value: filtroCliente,
          items: clientesDisponibles,
          onChanged: (value) => setState(() => filtroCliente = value),
        ),
        const SizedBox(height: 10),
        _dropdown(
          value: filtroMes,
          items: mesesDisponibles,
          onChanged: (value) => setState(() => filtroMes = value),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    Map<String, String>? labels,
    required ValueChanged<String> onChanged,
  }) {
    final validValue = items.contains(value) ? value : items.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: softText.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          isExpanded: true,
          dropdownColor: panelColor,
          iconEnabledColor: panelText,
          style: TextStyle(color: panelText, fontSize: 15),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(labels?[item] ?? item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
        ),
      ),
    );
  }

  Widget buildComparisonPanel() {
    final baseItems = tipoComparacion == "cliente"
        ? clientesDisponibles.where((e) => e != "Todos").toList()
        : mesesDisponibles.where((e) => e != "Todos").toList();

    final items = baseItems.isEmpty ? ["N/A"] : baseItems;

    if (!items.contains(comparacionA)) comparacionA = items.first;
    if (!items.contains(comparacionB)) comparacionB = items.length > 1 ? items[1] : items.first;

    return Card(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            SwitchListTile(
              value: comparacionActiva,
              onChanged: (value) => setState(() => comparacionActiva = value),
              title: Text("Comparar", style: TextStyle(color: panelText)),
            ),
            if (comparacionActiva) ...[
              _dropdown(
                value: tipoComparacion,
                items: const ["cliente", "mes"],
                labels: const {"cliente": "Cliente vs cliente", "mes": "Mes vs mes"},
                onChanged: (value) {
                  setState(() {
                    tipoComparacion = value;
                    comparacionA = "N/A";
                    comparacionB = "N/A";
                  });
                },
              ),
              const SizedBox(height: 10),
              _dropdown(
                value: comparacionA,
                items: items,
                onChanged: (value) => setState(() => comparacionA = value),
              ),
              const SizedBox(height: 10),
              _dropdown(
                value: comparacionB,
                items: items,
                onChanged: (value) => setState(() => comparacionB = value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildKPIs() {
    final datos = resumenFiltrado;
    final total = datos.fold<double>(0, (sum, e) => sum + _monto(e["total"]));

    return Row(
      key: ValueKey("$filtroCliente-$filtroMes-${datos.length}"),
      children: [
        Expanded(child: _kpiCard("Total", "\$${total.toStringAsFixed(2)}")),
        const SizedBox(width: 12),
        Expanded(child: _kpiCard("Clientes", "${datos.length}")),
      ],
    );
  }

  Widget _kpiCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTablaDetalle() {
    return Card(
      key: ValueKey("tabla-$filtroCliente-$filtroMes-${tablaFiltrada.length}"),
      color: isDark ? const Color(0xFFF8F4FF) : Colors.white,
      elevation: 4,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Cliente")),
            DataColumn(label: Text("Producto")),
            DataColumn(label: Text("Monto")),
            DataColumn(label: Text("Fecha")),
            DataColumn(label: Text("Mes")),
            DataColumn(label: Text("Categoría")),
            DataColumn(label: Text("Descripción")),
          ],
          rows: tablaFiltrada.map((item) {
            return DataRow(cells: [
              DataCell(Text((item["cliente"] ?? "N/A").toString())),
              DataCell(Text((item["producto"] ?? "N/A").toString())),
              DataCell(Text("\$${item["monto"] ?? 0}")),
              DataCell(Text((item["fecha"] ?? "N/A").toString())),
              DataCell(Text((item["mes"] ?? "N/A").toString())),
              DataCell(Text((item["categoria"] ?? "N/A").toString())),
              DataCell(
                SizedBox(
                  width: 220,
                  child: Text(
                    (item["descripcion"] ?? "N/A").toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget buildDashboardChart() {
    if (tipoGrafica == "pastel") return buildPieChart();
    if (tipoGrafica == "dona") return buildPieChart(dona: true);
    if (tipoGrafica == "lineas") return buildLineChart();
    if (tipoGrafica == "dispersion") return buildScatterChart();
    if (tipoGrafica == "heatmap") return buildHeatmapCard();

    if (tipoGrafica == "combinado") {
      return Column(
        children: [
          buildBarChart(),
          const SizedBox(height: 20),
          buildPieChart(dona: true),
          const SizedBox(height: 20),
          buildLineChart(),
          const SizedBox(height: 20),
          buildScatterChart(),
          const SizedBox(height: 20),
          buildHeatmapCard(),
        ],
      );
    }

    return buildBarChart();
  }

  Widget chartCard({required Widget child, double height = 300}) {
    return Card(
      color: panelColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(height: height, child: child),
      ),
    );
  }

  Widget buildBarChart() {
    final datos = resumenFiltrado;
    if (datos.isEmpty) return const SizedBox.shrink();

    final maxValue = datos.map((e) => _monto(e["total"])).reduce((a, b) => a > b ? a : b);

    if (datos.length == 1) {
      final cliente = (datos[0]["cliente"] ?? "N/A").toString();
      final total = _monto(datos[0]["total"]);
      return Card(
        color: panelColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cliente, style: TextStyle(color: panelText, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text("\$${total.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const LinearProgressIndicator(value: 1, minHeight: 28),
            ],
          ),
        ),
      );
    }

    return chartCard(
      child: BarChart(
        BarChartData(
          maxY: maxValue <= 0 ? 10 : maxValue * 1.25,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: softText.withOpacity(0.18), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: _chartTitles(datos),
          barGroups: List.generate(datos.length, (i) {
            final value = _monto(datos[i]["total"]);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 18,
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.purple.shade400],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 450),
      ),
    );
  }

  FlTitlesData _chartTitles(List<Map<String, dynamic>> datos) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 52,
          getTitlesWidget: (value, _) => Text(
            "\$${value.toInt()}",
            style: TextStyle(color: softText, fontSize: 10),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 76,
          interval: 1,
          getTitlesWidget: (value, _) {
            final index = value.round();
            if (value != index.toDouble() || index < 0 || index >= datos.length) {
              return const SizedBox.shrink();
            }
            final cliente = (datos[index]["cliente"] ?? "N/A").toString();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Transform.rotate(
                angle: -0.65,
                child: SizedBox(
                  width: 90,
                  child: Text(
                    cliente,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: softText, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildPieChart({bool dona = false}) {
    final datos = resumenFiltrado;
    if (datos.isEmpty) return const SizedBox.shrink();

    final total = datos.fold<double>(0, (sum, e) => sum + _monto(e["total"]));
    final colors = [
      const Color(0xFF00D4FF),
      const Color(0xFFB84DFF),
      const Color(0xFFFFB86C),
      const Color(0xFF50FA7B),
      const Color(0xFFFF6B6B),
      const Color(0xFF8BE9FD),
    ];

    return Card(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 260,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: dona ? 70 : 0,
                  sections: List.generate(datos.length, (i) {
                    final value = _monto(datos[i]["total"]);
                    final percent = total == 0 ? 0 : (value / total) * 100;
                    return PieChartSectionData(
                      value: value,
                      color: colors[i % colors.length],
                      title: "${percent.toStringAsFixed(0)}%",
                      radius: 82,
                      titleStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  }),
                ),
                duration: const Duration(milliseconds: 450),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(datos.length, (i) {
              final cliente = (datos[i]["cliente"] ?? "N/A").toString();
              final value = _monto(datos[i]["total"]);
              return Row(
                children: [
                  Container(width: 12, height: 12, color: colors[i % colors.length]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cliente, style: TextStyle(color: softText), overflow: TextOverflow.ellipsis)),
                  Text("\$${value.toStringAsFixed(2)}", style: TextStyle(color: panelText)),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget buildLineChart() {
    final porMes = <String, double>{};
    for (final item in tablaFiltrada) {
      final mes = (item["mes"] ?? "N/A").toString();
      porMes[mes] = (porMes[mes] ?? 0) + _monto(item["monto"]);
    }
    final meses = porMes.keys.toList()..sort();
    if (meses.isEmpty) return const SizedBox.shrink();

    final spots = List.generate(meses.length, (i) => FlSpot(i.toDouble(), porMes[meses[i]] ?? 0));
    final maxY = porMes.values.fold<double>(0, (a, b) => a > b ? a : b);

    return chartCard(
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 10 : maxY * 1.25,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: _monthTitles(meses),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 4,
              color: const Color(0xFF00D4FF),
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF00D4FF).withOpacity(0.18)),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 450),
      ),
    );
  }

  FlTitlesData _monthTitles(List<String> meses) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 52,
          getTitlesWidget: (value, _) => Text("\$${value.toInt()}", style: TextStyle(color: softText, fontSize: 10)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 46,
          interval: 1,
          getTitlesWidget: (value, _) {
            final i = value.toInt();
            if (i < 0 || i >= meses.length || value != i.toDouble()) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(meses[i], style: TextStyle(color: softText, fontSize: 10)),
            );
          },
        ),
      ),
    );
  }

  Widget buildScatterChart() {
    final datos = tablaFiltrada;
    if (datos.isEmpty) return const SizedBox.shrink();

    final spots = List.generate(datos.length, (i) => ScatterSpot(i.toDouble(), _monto(datos[i]["monto"])));
    final maxY = datos.fold<double>(0, (max, item) => _monto(item["monto"]) > max ? _monto(item["monto"]) : max);

    return chartCard(
      child: ScatterChart(
        ScatterChartData(
          minY: 0,
          maxY: maxY <= 0 ? 10 : maxY * 1.25,
          scatterSpots: spots,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget buildHeatmapCard() {
    final datos = tablaFiltrada;
    if (datos.isEmpty) return const SizedBox.shrink();

    final clientes = datos.map((e) => (e["cliente"] ?? "N/A").toString()).toSet().toList()..sort();
    final meses = datos.map((e) => (e["mes"] ?? "N/A").toString()).toSet().toList()..sort();

    final acumulado = <String, double>{};
    double maxValue = 0;

    for (final item in datos) {
      final cliente = (item["cliente"] ?? "N/A").toString();
      final mes = (item["mes"] ?? "N/A").toString();
      final key = "$cliente|$mes";
      final value = (acumulado[key] ?? 0) + _monto(item["monto"]);
      acumulado[key] = value;
      if (value > maxValue) maxValue = value;
    }

    Color cellColor(double value) {
      if (maxValue <= 0 || value <= 0) return softText.withOpacity(0.08);
      final intensity = (value / maxValue).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFF102033), const Color(0xFFB84DFF), intensity)!;
    }

    return Card(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Heatmap cliente / mes", style: TextStyle(color: panelText, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  const SizedBox(width: 110),
                  ...meses.map((mes) => SizedBox(width: 80, child: Text(mes, textAlign: TextAlign.center, style: TextStyle(color: softText, fontSize: 10)))),
                ],
              ),
              const SizedBox(height: 8),
              ...clientes.map((cliente) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 110, child: Text(cliente, style: TextStyle(color: softText, fontSize: 10), overflow: TextOverflow.ellipsis)),
                      ...meses.map((mes) {
                        final value = acumulado["$cliente|$mes"] ?? 0;
                        return Container(
                          width: 80,
                          height: 42,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(color: cellColor(value), borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: Text(value == 0 ? "" : "\$${value.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildComparisonChart() {
    if (tipoComparacion == "mes") return buildCompareByMonth();
    return buildCompareByClient();
  }

  Widget buildCompareByClient() {
    final selected = [comparacionA, comparacionB];
    final values = selected.map((cliente) {
      return tabla
          .where((e) => (e["cliente"] ?? "N/A").toString() == cliente)
          .fold<double>(0, (sum, e) => sum + _monto(e["monto"]));
    }).toList();

    return buildSimpleCompareBars(selected, values);
  }

  Widget buildCompareByMonth() {
    final selected = [comparacionA, comparacionB];
    final values = selected.map((mes) {
      return tabla
          .where((e) => (e["mes"] ?? "N/A").toString() == mes)
          .fold<double>(0, (sum, e) => sum + _monto(e["monto"]));
    }).toList();

    return buildSimpleCompareBars(selected, values);
  }

  Widget buildSimpleCompareBars(List<String> labels, List<double> values) {
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);

    return chartCard(
      child: BarChart(
        BarChartData(
          maxY: maxValue <= 0 ? 10 : maxValue * 1.25,
          barGroups: List.generate(labels.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 34,
                  color: i == 0 ? const Color(0xFF00D4FF) : const Color(0xFFB84DFF),
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(labels[i], style: TextStyle(color: softText, fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
        duration: const Duration(milliseconds: 450),
      ),
    );
  }

  Widget buildChatCard() {
    return Card(
      color: isDark ? const Color(0xFFF8F4FF) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: preguntaController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(hintText: "Pregunta a la IA"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: cargando ? null : preguntarIA,
              child: const Text("Preguntar"),
            ),
            const SizedBox(height: 10),
            Text(respuestaIA),
          ],
        ),
      ),
    );
  }
}
