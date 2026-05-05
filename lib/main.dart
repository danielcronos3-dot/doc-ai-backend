import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const endpointChat = "/chat";
const appName = "NexaDash AI";
const biYellow = Color(0xFFF2C811);
const biCyan = Color(0xFF00B7C3);
const biInk = Color(0xFF111827);
const biPanel = Color(0xFF171B26);
const feedbackEmail = "danielcronos3@gmail.com";
const platformChannel = MethodChannel("nexadash/native");

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
  final List<String> insights;

  SavedReport({
    required this.nombre,
    required this.fecha,
    required this.tabla,
    required this.resumen,
    required this.tipoGrafica,
    required this.insights,
  });

  Map<String, dynamic> toJson() {
    return {
      "nombre": nombre,
      "fecha": fecha.toIso8601String(),
      "tabla": tabla,
      "resumen": resumen,
      "tipoGrafica": tipoGrafica,
      "insights": insights,
    };
  }

  factory SavedReport.fromJson(Map<String, dynamic> json) {
    return SavedReport(
      nombre: json["nombre"] ?? "Reporte",
      fecha: DateTime.tryParse(json["fecha"] ?? "") ?? DateTime.now(),
      tabla: List<Map<String, dynamic>>.from(json["tabla"] ?? []),
      resumen: List<Map<String, dynamic>>.from(json["resumen"] ?? []),
      tipoGrafica: json["tipoGrafica"] == "lineas"
          ? "ranking"
          : json["tipoGrafica"] ?? "barras",
      insights: List<String>.from(json["insights"] ?? []),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B1020),
      colorScheme: ColorScheme.fromSeed(
        seedColor: biYellow,
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
        seedColor: biYellow,
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

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 54});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(
          colors: [biYellow, biCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: biYellow.withValues(alpha: 0.28),
            blurRadius: size * 0.26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: size * 0.24,
            bottom: size * 0.22,
            child: _brandBar(size: size, height: 0.42),
          ),
          Positioned(
            left: size * 0.43,
            bottom: size * 0.22,
            child: _brandBar(size: size, height: 0.58),
          ),
          Positioned(
            left: size * 0.62,
            bottom: size * 0.22,
            child: _brandBar(size: size, height: 0.74),
          ),
          Positioned(
            right: size * 0.18,
            top: size * 0.16,
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: size * 0.24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandBar({required double size, required double height}) {
    return Container(
      width: size * 0.12,
      height: size * height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.08),
      ),
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
        SnackBar(content: Text("No se pudo entrar como invitado: $e")),
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

    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );

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
      appBar: AppBar(title: const Text(appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 72),
              const SizedBox(height: 14),
              Text(
                appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
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
  int tabIndex = 0;
  List<String> insights = [];

  String filtroCliente = "Todos";
  String filtroMes = "Todos";
  String tipoGrafica = "barras";

  bool comparacionActiva = false;
  bool comparacionArchivosActiva = false;
  String tipoComparacion = "cliente";
  String comparacionA = "N/A";
  String comparacionB = "N/A";

  String estadoArchivo = "";
  String respuestaIA = "";
  bool cargando = false;

  final preguntaController = TextEditingController();
  final nombreReporteController = TextEditingController(text: "Reporte");
  String get userId => widget.user.uid;
  String get historialKey => "historial_$userId";
  Map<String, dynamic> calidadDatos = {};

  Future<void> cargarHistorialLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(historialKey);

    if (raw == null || raw.isEmpty) return;

    try {
      final lista = jsonDecode(raw) as List;

      setState(() {
        historial = lista
            .map(
              (item) => SavedReport.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      });
    } catch (e) {
      print("ERROR CARGANDO HISTORIAL: $e");
    }
  }

  Future<void> guardarHistorialLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = jsonEncode(
      historial.map((reporte) => reporte.toJson()).toList(),
    );

    await prefs.setString(historialKey, raw);
  }

  Future<Map<String, String>> getJsonHeaders() async {
    final token = await widget.user.getIdToken();

    return {
      "Content-Type": "application/json",
      "X-User-Id": userId,
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<Map<String, String>> getUserHeaders() async {
    final token = await widget.user.getIdToken();

    return {
      "X-User-Id": userId,
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<void> cerrarSesion() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> compartirArchivoNativo({
    required String path,
    required String title,
    required String text,
  }) async {
    await platformChannel.invokeMethod("shareFile", {
      "path": path,
      "title": title,
      "text": text,
    });
  }

  Future<void> enviarFeedback() async {
    final userEmail = widget.user.email ?? "Invitado";
    final body =
        """
Hola, quiero enviar una sugerencia o reporte sobre NexaDash AI.

Usuario: $userEmail
UID: $userId

Escribe aqui tu comentario:
""";

    try {
      await platformChannel.invokeMethod("sendFeedback", {
        "email": feedbackEmail,
        "subject": "Sugerencia NexaDash AI",
        "body": body,
      });
    } catch (e) {
      print("ERROR FEEDBACK: $e");
      setState(
        () => estadoArchivo = "No se pudo abrir el correo de sugerencias",
      );
    }
  }

  @override
  void initState() {
    super.initState();
    cargarHistorialLocal();
  }

  @override
  void dispose() {
    preguntaController.dispose();
    nombreReporteController.dispose();
    super.dispose();
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get pageTop =>
      isDark ? const Color(0xFF0B1020) : const Color(0xFFF6F8FC);
  Color get pageBottom =>
      isDark ? const Color(0xFF14213D) : const Color(0xFFEAF0F8);
  Color get panelColor => isDark ? biPanel : Colors.white;
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

  List<String> get archivosDisponibles {
    final archivos = tabla
        .map((e) => (e["archivo"] ?? "N/A").toString())
        .where((e) => e.trim().isNotEmpty && e != "N/A")
        .toSet()
        .toList();
    archivos.sort();
    return archivos;
  }

  Future<void> subirArchivos(
    List<PlatformFile> files, {
    bool agregar = false,
  }) async {
    setState(() {
      cargando = true;
      estadoArchivo = "Subiendo archivos...";
    });

    try {
      print("ENTRÉ A subirArchivos");
      print("Enviando ${files.length} archivos");

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload?append=${agregar ? "true" : "false"}'),
      );

      request.headers.addAll(await getUserHeaders());

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
            headers: await getJsonHeaders(),
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
          insights = List<String>.from(data["insights"] ?? []);
          calidadDatos = Map<String, dynamic>.from(data["calidad"] ?? {});
          filtroCliente = "Todos";
          filtroMes = "Todos";
          comparacionActiva = false;
          comparacionArchivosActiva = false;

          if (tabla.isEmpty) {
            estadoArchivo = data["mensaje"] ?? "No se encontraron datos";
          } else {
            estadoArchivo = "Dashboard actualizado";
            tabIndex = 1;
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

  Future<void> seleccionarArchivo({
    bool reemplazar = true,
    bool comparar = false,
  }) async {
    print("ABRIENDO FILE PICKER");

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'bmp',
        'xlsx',
        'xls',
        'csv',
        'sql',
        'txt',
        'json',
        'xml',
        'html',
        'md',
      ],
    );

    print("FILE PICKER TERMINO");

    if (result == null || result.files.isEmpty) {
      print("SE CANCELO EL PICKER");
      setState(() => estadoArchivo = "Seleccion cancelada");
      return;
    }

    if (comparar && result.files.length < 2) {
      setState(
        () => estadoArchivo = "Selecciona minimo 2 archivos para comparar",
      );
      return;
    }

    print("ARCHIVOS SELECCIONADOS: ${result.files.length}");

    for (final file in result.files) {
      print("Archivo: ${file.name}");
      print("Path: ${file.path}");
      print("Bytes: ${file.bytes?.length}");
    }

    if (reemplazar) {
      await limpiarDatos(silencioso: true);
    }

    setState(() => comparacionArchivosActiva = comparar);

    await subirArchivos(result.files, agregar: !reemplazar);
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
            [
              "barras",
              "pastel",
              "dona",
              "ranking",
              "dispersion",
              "heatmap",
              "combinado",
            ].contains(grafica)) {
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

  String generarRespuestaLocalIA(String pregunta) {
    if (tablaFiltrada.isEmpty) {
      return "Sube un archivo o abre un reporte guardado primero.";
    }

    final datos = resumenFiltrado;
    final total = datos.fold<double>(
      0,
      (sum, item) => sum + _monto(item["total"]),
    );

    Map<String, dynamic>? top;
    for (final item in datos) {
      if (top == null || _monto(item["total"]) > _monto(top["total"])) {
        top = item;
      }
    }

    final topCliente = (top?["cliente"] ?? "N/A").toString();
    final topMonto = _monto(top?["total"] ?? 0);
    final porcentaje = total > 0 ? (topMonto / total) * 100 : 0;
    final preguntaLower = pregunta.toLowerCase();

    final porMes = <String, double>{};
    for (final item in tablaFiltrada) {
      final mes = (item["mes"] ?? "N/A").toString();
      porMes[mes] = (porMes[mes] ?? 0) + _monto(item["monto"]);
    }

    String mejorMes = "N/A";
    double mejorMesTotal = 0;
    porMes.forEach((mes, monto) {
      if (monto > mejorMesTotal) {
        mejorMes = mes;
        mejorMesTotal = monto;
      }
    });

    String enfoque = "Resumen ejecutivo";
    String accion =
        "Revisa los clientes con mayor monto y prioriza seguimiento comercial.";

    if (preguntaLower.contains("riesgo")) {
      enfoque = "Riesgos detectados";
      accion = porcentaje > 50
          ? "Reduce dependencia de $topCliente creando seguimiento para clientes medianos."
          : "Manten monitoreo de concentracion por cliente y variacion mensual.";
    } else if (preguntaLower.contains("oportunidad")) {
      enfoque = "Oportunidades comerciales";
      accion =
          "Crea una campana para clientes recurrentes y ofrece paquetes a los de mayor monto.";
    } else if (preguntaLower.contains("grafica")) {
      enfoque = "Mejor visualizacion";
      accion = porMes.length > 1
          ? "Usa Ranking para ver clientes prioritarios o Barras para comparar clientes."
          : "Usa Barras o Dona para comparar participacion por cliente.";
    } else if (preguntaLower.contains("accion")) {
      enfoque = "Acciones recomendadas";
      accion =
          "1. Contacta a $topCliente. 2. Revisa meses de mayor ingreso. 3. Guarda este reporte y compartelo con el equipo.";
    }

    return """
$enfoque

1. Hallazgo principal
El reporte contiene ${tablaFiltrada.length} registros, ${datos.length} clientes detectados y un monto total de ${_money(total)}.

2. Evidencia concreta
El cliente principal es $topCliente con ${_money(topMonto)}, equivalente al ${porcentaje.toStringAsFixed(1)}% del total. El mejor mes detectado es $mejorMes con ${_money(mejorMesTotal)}.

3. Riesgo u oportunidad
${porcentaje > 50 ? "Hay alta concentracion en un solo cliente, lo que puede representar dependencia." : "La distribucion no depende demasiado de un solo cliente, lo que permite buscar crecimiento ordenado."}

4. Accion recomendada
$accion
""";
  }

  Future<void> preguntarIA() async {
    final pregunta = preguntaController.text.trim();
    if (pregunta.isEmpty) return;

    setState(() {
      cargando = true;
      respuestaIA = "Pensando...";
    });

    try {
      final preguntaConControl =
          """
Actua como asesor ejecutivo de datos dentro de $appName.

Pregunta del usuario:
$pregunta

Usa el dashboard actual como fuente principal. Responde con:
1. Hallazgo principal.
2. Evidencia concreta con montos, clientes, meses o registros.
3. Riesgo u oportunidad.
4. Accion recomendada.

Tambien puedes sugerir que grafica conviene usar y que filtro ayuda a entender mejor el reporte.
No inventes datos. Si algo no aparece, dilo claro.

Si el usuario pide cambiar el dashboard, al final responde tambien un JSON valido con esta forma:
{"tipoGrafica":"barras|pastel|dona|ranking|dispersion|heatmap|combinado","filtroCliente":"Todos","filtroMes":"Todos"}
Solo incluye valores existentes si los conoces.
""";

      final response = await http
          .post(
            Uri.parse("$baseUrl$endpointChat"),
            headers: await getJsonHeaders(),
            body: jsonEncode({
              "mensaje": preguntaConControl,
              "dashboard": {
                "data": tabla,
                "resumen": resumenFiltrado,
                "insights": insights,
                "calidad": calidadDatos,
              },
            }),
          )
          .timeout(const Duration(seconds: 240));
      print("CHAT STATUS: ${response.statusCode}");
      print("CHAT BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final respuesta = (data["respuesta"] ?? "Sin respuesta").toString();
        final debeUsarLocal =
            tablaFiltrada.isNotEmpty &&
            respuesta.toLowerCase().contains("sube archivo");
        final respuestaFinal = debeUsarLocal
            ? generarRespuestaLocalIA(pregunta)
            : respuesta;

        setState(() => respuestaIA = respuestaFinal);
        aplicarComandoDashboard(respuestaFinal.toString());
      } else {
        setState(
          () => respuestaIA = "Error del servidor: ${response.statusCode}",
        );
      }
    } catch (e) {
      if (tablaFiltrada.isNotEmpty) {
        setState(() => respuestaIA = generarRespuestaLocalIA(pregunta));
      } else {
        setState(() => respuestaIA = "Error conectando con la IA");
      }
    }

    setState(() => cargando = false);
  }

  Future<void> limpiarDatos({bool silencioso = false}) async {
    setState(() {
      cargando = true;
      if (!silencioso) {
        estadoArchivo = "Limpiando datos...";
      }
    });

    try {
      await http
          .post(Uri.parse("$baseUrl/reset"), headers: await getUserHeaders())
          .timeout(const Duration(seconds: 30));
    } catch (_) {}

    setState(() {
      tabla = [];
      resumen = [];
      insights = [];
      calidadDatos = {};
      filtroCliente = "Todos";
      filtroMes = "Todos";
      respuestaIA = "";
      comparacionArchivosActiva = false;
      estadoArchivo = silencioso
          ? "Listo para nuevo archivo"
          : "Datos eliminados";
      cargando = false;
    });
  }

  Future<void> descargardashboard() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/descargar-dashboard?tipo=$tipoGrafica"),
        headers: await getUserHeaders(),
      );

      print("DASHBOARD DOWNLOAD STATUS: ${response.statusCode}");
      print("DASHBOARD CONTENT TYPE: ${response.headers["content-type"]}");

      if (response.statusCode == 200 &&
          (response.headers["content-type"] ?? "").contains("image/png")) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
          "${dir.path}/dashboard_${DateTime.now().millisecondsSinceEpoch}.png",
        );

        await file.writeAsBytes(response.bodyBytes);
        await OpenFilex.open(file.path);
      } else {
        print("DASHBOARD ERROR BODY: ${response.body}");
        setState(() => estadoArchivo = "No se pudo descargar el dashboard");
      }
    } catch (e) {
      print("ERROR DESCARGAR DASHBOARD: $e");
      setState(() => estadoArchivo = "Error descargando dashboard");
    }
  }

  Future<void> descargarexcel() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/descargar-excel"),
        headers: await getUserHeaders(),
      );

      print("EXCEL DOWNLOAD STATUS: ${response.statusCode}");
      print("EXCEL CONTENT TYPE: ${response.headers["content-type"]}");

      final contentType = response.headers["content-type"] ?? "";

      if (response.statusCode == 200 && contentType.contains("spreadsheetml")) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
          "${dir.path}/reporte_${DateTime.now().millisecondsSinceEpoch}.xlsx",
        );

        await file.writeAsBytes(response.bodyBytes);
        await OpenFilex.open(file.path);
      } else {
        print("EXCEL ERROR BODY: ${response.body}");
        setState(() => estadoArchivo = "No se pudo descargar el Excel");
      }
    } catch (e) {
      print("ERROR DESCARGAR EXCEL: $e");
      setState(() => estadoArchivo = "Error descargando Excel");
    }
  }

  String _pdfText(dynamic value) {
    return (value ?? "N/A").toString().replaceAll(RegExp(r"[^\x20-\x7E]"), "");
  }

  Future<void> preguntarRapido(String pregunta) async {
    preguntaController.text = pregunta;
    await preguntarIA();
  }

  String _money(dynamic value) {
    return "\$${_monto(value).toStringAsFixed(2)}";
  }

  pw.Widget _pdfLogo() {
    return pw.Container(
      width: 46,
      height: 46,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex("F2C811"),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          _pdfBar(16),
          pw.SizedBox(width: 4),
          _pdfBar(25),
          pw.SizedBox(width: 4),
          _pdfBar(32),
        ],
      ),
    );
  }

  pw.Widget _pdfBar(double height) {
    return pw.Container(
      width: 7,
      height: height,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(3),
      ),
    );
  }

  Future<void> descargarPdf() async {
    if (tablaFiltrada.isEmpty) {
      setState(() => estadoArchivo = "No hay datos para exportar PDF");
      return;
    }

    try {
      setState(() => estadoArchivo = "Generando PDF...");

      final pdf = pw.Document();
      final datos = tablaFiltrada;
      final resumenPdf = resumenFiltrado;
      final total = resumenPdf.fold<double>(
        0,
        (sum, item) => sum + _monto(item["total"]),
      );

      String topCliente = "N/A";
      if (resumenPdf.isNotEmpty) {
        Map<String, dynamic> top = resumenPdf.first;
        for (final item in resumenPdf.skip(1)) {
          if (_monto(item["total"]) > _monto(top["total"])) {
            top = item;
          }
        }
        topCliente = (top["cliente"] ?? "N/A").toString();
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(34),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 14),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              children: [
                _pdfLogo(),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      appName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex("10172A"),
                      ),
                    ),
                    pw.Text(
                      "Reporte ejecutivo inteligente",
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Text(
                  DateTime.now().toString().substring(0, 16),
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "$appName | Pagina ${context.pageNumber} de ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 16),
            pw.Text(
              nombreReporteController.text.trim().isEmpty
                  ? "Dashboard ejecutivo"
                  : nombreReporteController.text.trim(),
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              "Documento generado con los filtros actuales del dashboard.",
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              children: [
                _pdfKpi("Monto total", _money(total)),
                pw.SizedBox(width: 10),
                _pdfKpi("Clientes", "${resumenPdf.length}"),
                pw.SizedBox(width: 10),
                _pdfKpi("Top cliente", topCliente),
              ],
            ),
            pw.SizedBox(height: 22),
            if (calidadDatos.isNotEmpty) ...[
              pw.Text(
                "Calidad de datos",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                "Registros: ${calidadDatos["registros"] ?? datos.length}",
              ),
              pw.Text(
                "Clientes detectados: ${calidadDatos["clientes_detectados"] ?? resumenPdf.length}",
              ),
              pw.Text(
                "Monto total detectado: ${_money(calidadDatos["monto_total"] ?? total)}",
              ),
              pw.SizedBox(height: 16),
            ],
            if (insights.isNotEmpty) ...[
              pw.Text(
                _pdfText("Insights"),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              ...insights
                  .take(6)
                  .map(
                    (item) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Text("- ${_pdfText(item)}"),
                    ),
                  ),
              pw.SizedBox(height: 16),
            ],
            pw.Text(
              _pdfText("Resumen por cliente"),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ["Cliente", "Total"],
              data: resumenPdf
                  .map(
                    (item) => [
                      _pdfText(item["cliente"] ?? "N/A"),
                      _money(item["total"]),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex("10172A"),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex("F8FAFC"),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              _pdfText("Detalle"),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ["Cliente", "Producto", "Monto", "Fecha"],
              data: datos
                  .take(28)
                  .map(
                    (item) => [
                      _pdfText(item["cliente"] ?? "N/A"),
                      _pdfText(item["producto"] ?? "N/A"),
                      _money(item["monto"]),
                      _pdfText(item["fecha"] ?? "N/A"),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex("F2C811"),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex("F8FAFC"),
              ),
            ),
          ],
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        "${dir.path}/reporte_nexadash_ai_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );

      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
      setState(() => estadoArchivo = "PDF generado");
    } catch (e) {
      print("ERROR DESCARGAR PDF LOCAL: $e");
      setState(() => estadoArchivo = "Error generando PDF");
    }
  }

  pw.Widget _pdfKpi(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex("F8FAFC"),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColor.fromHex("CBD5E1")),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              value,
              maxLines: 2,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<File> crearPdfArchivo({
    required String nombre,
    required List<Map<String, dynamic>> datos,
    required List<Map<String, dynamic>> resumenPdf,
    required List<String> pdfInsights,
  }) async {
    final pdf = pw.Document();
    final total = resumenPdf.fold<double>(
      0,
      (sum, item) => sum + _monto(item["total"]),
    );

    String topCliente = "N/A";
    if (resumenPdf.isNotEmpty) {
      Map<String, dynamic> top = resumenPdf.first;
      for (final item in resumenPdf.skip(1)) {
        if (_monto(item["total"]) > _monto(top["total"])) {
          top = item;
        }
      }
      topCliente = (top["cliente"] ?? "N/A").toString();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 14),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
            ),
          ),
          child: pw.Row(
            children: [
              _pdfLogo(),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    appName,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex("10172A"),
                    ),
                  ),
                  pw.Text(
                    "Reporte ejecutivo inteligente",
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Text(
                DateTime.now().toString().substring(0, 16),
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            "$appName | Pagina ${context.pageNumber} de ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 16),
          pw.Text(
            _pdfText(nombre),
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            "Reporte generado desde el dashboard guardado.",
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              _pdfKpi("Monto total", _money(total)),
              pw.SizedBox(width: 10),
              _pdfKpi("Clientes", "${resumenPdf.length}"),
              pw.SizedBox(width: 10),
              _pdfKpi("Top cliente", topCliente),
            ],
          ),
          pw.SizedBox(height: 22),
          if (pdfInsights.isNotEmpty) ...[
            pw.Text(
              _pdfText("Insights"),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            ...pdfInsights
                .take(6)
                .map(
                  (item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Text("- ${_pdfText(item)}"),
                  ),
                ),
            pw.SizedBox(height: 16),
          ],
          pw.Text(
            _pdfText("Resumen por cliente"),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ["Cliente", "Total"],
            data: resumenPdf
                .map(
                  (item) => [
                    _pdfText(item["cliente"] ?? "N/A"),
                    _money(item["total"]),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex("10172A"),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9),
            oddRowDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex("F8FAFC"),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            _pdfText("Detalle"),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ["Cliente", "Producto", "Monto", "Fecha"],
            data: datos
                .take(28)
                .map(
                  (item) => [
                    _pdfText(item["cliente"] ?? "N/A"),
                    _pdfText(item["producto"] ?? "N/A"),
                    _money(item["monto"]),
                    _pdfText(item["fecha"] ?? "N/A"),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex("F2C811"),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex("F8FAFC"),
            ),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final safeName = nombre.replaceAll(RegExp(r"[^A-Za-z0-9_-]+"), "_");
    final file = File(
      "${dir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> compartirReporteGuardado(SavedReport reporte) async {
    try {
      final file = await crearPdfArchivo(
        nombre: reporte.nombre,
        datos: List<Map<String, dynamic>>.from(reporte.tabla),
        resumenPdf: List<Map<String, dynamic>>.from(reporte.resumen),
        pdfInsights: List<String>.from(reporte.insights),
      );

      try {
        await compartirArchivoNativo(
          path: file.path,
          title: "$appName - ${reporte.nombre}",
          text: "Te comparto este reporte de $appName: ${reporte.nombre}",
        );
        setState(() => estadoArchivo = "Reporte listo para compartir");
      } catch (shareError) {
        print("ERROR COMPARTIR NATIVO: $shareError");
        setState(
          () => estadoArchivo =
              "No se abrio el menu de compartir. Reinstala con flutter clean y flutter run",
        );
      }
    } catch (e) {
      print("ERROR COMPARTIR REPORTE: $e");
      setState(() => estadoArchivo = "No se pudo compartir el reporte");
    }
  }

  Future<void> eliminarReporteGuardado(int index) async {
    if (index < 0 || index >= historial.length) return;

    final nombre = historial[index].nombre;
    setState(() {
      historial.removeAt(index);
      estadoArchivo = "Reporte eliminado: $nombre";
    });

    await guardarHistorialLocal();
  }

  void guardarDashboard() async {
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
          insights: List<String>.from(insights),
        ),
      );
      estadoArchivo = "Dashboard guardado";
    });

    await guardarHistorialLocal();
  }

  void cargarReporte(SavedReport reporte) {
    setState(() {
      tabla = List<Map<String, dynamic>>.from(reporte.tabla);
      resumen = List<Map<String, dynamic>>.from(reporte.resumen);
      insights = List<String>.from(reporte.insights);
      tipoGrafica = reporte.tipoGrafica;
      filtroCliente = "Todos";
      filtroMes = "Todos";
      estadoArchivo = "Reporte cargado: ${reporte.nombre}";
      tabIndex = 1;
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
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        foregroundColor: panelText,
        title: Text(
          "$appName - ${widget.user.email ?? "Invitado"}",
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
            tooltip: "Cerrar sesion",
            icon: const Icon(Icons.logout),
            onPressed: cerrarSesion,
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
          child: IndexedStack(
            index: tabIndex,
            children: [
              buildFilesTab(),
              buildDashboardTab(),
              buildChatTab(),
              buildHistoryTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: isDark ? const Color(0xFF171319) : Colors.white,
        indicatorColor: biYellow.withValues(alpha: isDark ? 0.22 : 0.32),
        selectedIndex: tabIndex,
        onDestinationSelected: (index) {
          setState(() => tabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_open),
            label: "Archivos",
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          NavigationDestination(icon: Icon(Icons.smart_toy), label: "IA"),
          NavigationDestination(icon: Icon(Icons.history), label: "Historial"),
        ],
      ),
    );
  }

  Widget _mainButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: biYellow,
        foregroundColor: const Color(0xFF111827),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              decoration: const InputDecoration(
                labelText: "Nombre del reporte",
              ),
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Compartir",
                      icon: const Icon(Icons.share),
                      onPressed: () => compartirReporteGuardado(reporte),
                    ),
                    IconButton(
                      tooltip: "Eliminar",
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          eliminarReporteGuardado(historial.indexOf(reporte)),
                    ),
                    const Icon(Icons.open_in_new),
                  ],
                ),
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
      "ranking": "Ranking",
      "dispersion": "Dispersion",
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
              child: Text(
                labels?[item] ?? item,
                overflow: TextOverflow.ellipsis,
              ),
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
    if (!items.contains(comparacionB))
      comparacionB = items.length > 1 ? items[1] : items.first;

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
                labels: const {
                  "cliente": "Cliente vs cliente",
                  "mes": "Mes vs mes",
                },
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

  int get scoreNegocio {
    if (tablaFiltrada.isEmpty) return 0;

    var score = 100;
    final datos = resumenFiltrado;
    final total = datos.fold<double>(
      0,
      (sum, item) => sum + _monto(item["total"]),
    );

    if (total <= 0) score -= 35;
    if (datos.length <= 1) score -= 18;

    final top = datos.fold<double>(0, (max, item) {
      final value = _monto(item["total"]);
      return value > max ? value : max;
    });

    final concentracion = total > 0 ? top / total : 0;
    if (concentracion > 0.65) score -= 20;
    if (concentracion > 0.45) score -= 10;

    final sinFecha = tablaFiltrada.where((item) {
      final fecha = (item["fecha"] ?? "N/A").toString().trim();
      return fecha.isEmpty || fecha == "N/A";
    }).length;
    final sinFechaRatio = sinFecha / tablaFiltrada.length;
    if (sinFechaRatio > 0.35) score -= 15;
    if (sinFechaRatio > 0.10) score -= 7;

    final meses = tablaFiltrada
        .map((item) => (item["mes"] ?? "N/A").toString())
        .where((mes) => mes.isNotEmpty && mes != "N/A")
        .toSet()
        .length;
    if (meses <= 1) score -= 6;

    return score.clamp(0, 100);
  }

  List<Map<String, dynamic>> get alertasNegocio {
    if (tablaFiltrada.isEmpty) return [];

    final alertas = <Map<String, dynamic>>[];
    final datos = resumenFiltrado;
    final total = datos.fold<double>(
      0,
      (sum, item) => sum + _monto(item["total"]),
    );

    if (datos.isNotEmpty && total > 0) {
      Map<String, dynamic> top = datos.first;
      for (final item in datos.skip(1)) {
        if (_monto(item["total"]) > _monto(top["total"])) top = item;
      }

      final pct = (_monto(top["total"]) / total) * 100;
      if (pct >= 50) {
        alertas.add({
          "title": "Cliente dominante",
          "detail":
              "${top["cliente"]} concentra ${pct.toStringAsFixed(1)}% del total.",
          "icon": Icons.account_balance,
          "color": biYellow,
        });
      }
    }

    final sinFecha = tablaFiltrada.where((item) {
      final fecha = (item["fecha"] ?? "N/A").toString().trim();
      return fecha.isEmpty || fecha == "N/A";
    }).length;
    if (sinFecha > 0) {
      alertas.add({
        "title": "Faltan fechas en datos",
        "detail": "$sinFecha registros no tienen fecha clara.",
        "icon": Icons.event_busy,
        "color": const Color(0xFFFFB020),
      });
    }

    final duplicadosBackend = (calidadDatos["duplicados"] is num)
        ? (calidadDatos["duplicados"] as num).toInt()
        : registrosDuplicados;
    if (duplicadosBackend > 0) {
      alertas.add({
        "title": "Datos duplicados",
        "detail": "$duplicadosBackend registros podrian estar repetidos.",
        "icon": Icons.content_copy,
        "color": const Color(0xFFFFB020),
      });
    }

    final fraudeBackend = (calidadDatos["posible_fraude"] is num)
        ? (calidadDatos["posible_fraude"] as num).toInt()
        : registrosSospechosos;
    if (fraudeBackend > 0) {
      alertas.add({
        "title": "Posible fraude o error",
        "detail": "$fraudeBackend montos son atipicos para este reporte.",
        "icon": Icons.gpp_maybe_outlined,
        "color": const Color(0xFFFF5C5C),
      });
    }

    final porMes = <String, double>{};
    for (final item in tablaFiltrada) {
      final mes = (item["mes"] ?? "N/A").toString();
      if (mes == "N/A" || mes.trim().isEmpty) continue;
      porMes[mes] = (porMes[mes] ?? 0) + _monto(item["monto"]);
    }

    final meses = porMes.keys.toList()..sort();
    if (meses.length >= 2) {
      final anterior = porMes[meses[meses.length - 2]] ?? 0;
      final actual = porMes[meses.last] ?? 0;
      if (anterior > 0 && actual < anterior) {
        final baja = ((anterior - actual) / anterior) * 100;
        alertas.add({
          "title": "Ventas bajaron este mes",
          "detail":
              "${meses.last} cayo ${baja.toStringAsFixed(1)}% contra ${meses[meses.length - 2]}.",
          "icon": Icons.trending_down,
          "color": const Color(0xFFFF5C5C),
        });
      }
    }

    if (alertas.isEmpty) {
      alertas.add({
        "title": "Sin alertas criticas",
        "detail":
            "El reporte no muestra senales urgentes con los datos actuales.",
        "icon": Icons.verified,
        "color": biCyan,
      });
    }

    return alertas.take(3).toList();
  }

  int get registrosDuplicados {
    final vistos = <String>{};
    var duplicados = 0;

    for (final item in tablaFiltrada) {
      final key = [
        (item["cliente"] ?? "N/A").toString().trim().toLowerCase(),
        (item["producto"] ?? "N/A").toString().trim().toLowerCase(),
        _monto(item["monto"]).toStringAsFixed(2),
        (item["fecha"] ?? "N/A").toString().trim(),
      ].join("|");

      if (!vistos.add(key)) duplicados++;
    }

    return duplicados;
  }

  int get registrosSospechosos {
    final montos = tablaFiltrada
        .map((item) => _monto(item["monto"]))
        .where((monto) => monto > 0)
        .toList();
    if (montos.length < 3) return 0;

    final promedio =
        montos.fold<double>(0, (sum, monto) => sum + monto) / montos.length;
    return montos.where((monto) => monto > promedio * 3 && monto > 1000).length;
  }

  String get riesgoAutomatico {
    if (registrosDuplicados > 0) {
      return "$registrosDuplicados registros parecen duplicados.";
    }
    if (registrosSospechosos > 0) {
      return "$registrosSospechosos montos se salen del patron normal.";
    }

    final alerta = alertasNegocio.firstWhere(
      (item) => item["color"] == const Color(0xFFFF5C5C),
      orElse: () => alertasNegocio.first,
    );
    return alerta["title"].toString();
  }

  String get oportunidadAutomatica {
    final datos = resumenFiltrado;
    if (datos.isEmpty) return "Aun no hay datos suficientes.";

    Map<String, dynamic> top = datos.first;
    for (final item in datos.skip(1)) {
      if (_monto(item["total"]) > _monto(top["total"])) top = item;
    }

    return "Prioriza ${(top["cliente"] ?? "el cliente principal")} y replica lo que mas compra.";
  }

  String get accionAutomatica {
    if (registrosDuplicados > 0 || registrosSospechosos > 0) {
      return "Revisa duplicados y montos atipicos antes de compartir el reporte.";
    }
    if (scoreNegocio < 70) {
      return "Filtra por cliente y mes para encontrar donde se pierde valor.";
    }
    return "Guarda este dashboard y compartelo como reporte ejecutivo.";
  }

  Widget buildAsesorAutomaticoCard() {
    final items = [
      {
        "label": "Riesgo",
        "value": riesgoAutomatico,
        "color": const Color(0xFFFF5C5C),
        "icon": Icons.warning_amber_rounded,
      },
      {
        "label": "Oportunidad",
        "value": oportunidadAutomatica,
        "color": biYellow,
        "icon": Icons.lightbulb_outline,
      },
      {
        "label": "Accion",
        "value": accionAutomatica,
        "color": const Color(0xFF34D399),
        "icon": Icons.task_alt,
      },
    ];

    return Card(
      color: panelColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Asesor de negocio automatico",
              style: TextStyle(
                color: panelText,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              final color = item["color"] as Color;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.13 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.34)),
                ),
                child: Row(
                  children: [
                    Icon(item["icon"] as IconData, color: color),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 96,
                      child: Text(
                        item["label"].toString(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item["value"].toString(),
                        style: TextStyle(color: panelText),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget buildBusinessHealthCard() {
    final score = scoreNegocio;
    final color = score >= 80
        ? const Color(0xFF34D399)
        : score >= 60
        ? biYellow
        : const Color(0xFFFF6B6B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: softText.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text(
                  "$score%",
                  style: TextStyle(
                    color: panelText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Salud del negocio",
                  style: TextStyle(
                    color: panelText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  score >= 80
                      ? "Operacion estable con senales sanas."
                      : score >= 60
                      ? "Hay oportunidades de mejora detectadas."
                      : "Requiere atencion: datos o concentracion presentan riesgo.",
                  style: TextStyle(color: softText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBusinessAlertsCard() {
    final alertas = alertasNegocio;

    return Card(
      color: panelColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: biYellow),
                const SizedBox(width: 8),
                Text(
                  "Alertas del negocio",
                  style: TextStyle(
                    color: panelText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alertas.map((alerta) {
              final color = alerta["color"] as Color;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.12 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(alerta["icon"] as IconData, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alerta["title"].toString(),
                            style: TextStyle(
                              color: panelText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alerta["detail"].toString(),
                            style: TextStyle(color: softText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget buildFileComparisonCard() {
    if (!comparacionArchivosActiva || archivosDisponibles.length < 2) {
      return const SizedBox.shrink();
    }

    final totalGeneral = tablaFiltrada.fold<double>(
      0,
      (sum, item) => sum + _monto(item["monto"]),
    );

    return Card(
      color: panelColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows, color: biYellow),
                const SizedBox(width: 8),
                Text(
                  "Comparacion de archivos",
                  style: TextStyle(
                    color: panelText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...archivosDisponibles.map((archivo) {
              final rows = tablaFiltrada
                  .where(
                    (item) => (item["archivo"] ?? "N/A").toString() == archivo,
                  )
                  .toList();
              final total = rows.fold<double>(
                0,
                (sum, item) => sum + _monto(item["monto"]),
              );
              final pct = totalGeneral <= 0
                  ? 0.0
                  : (total / totalGeneral).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            archivo,
                            style: TextStyle(
                              color: panelText,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "${rows.length} reg.  ${_money(total)}",
                          style: TextStyle(color: softText, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 9,
                        backgroundColor: softText.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          biYellow,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget buildMiniTutorialCard() {
    final steps = [
      {
        "icon": Icons.upload_file,
        "title": "Sube archivos",
        "text": "PDF, Excel, CSV, imagenes o texto.",
      },
      {
        "icon": Icons.auto_graph,
        "title": "Genera dashboard",
        "text": "NexaDash extrae datos y crea metricas.",
      },
      {
        "icon": Icons.smart_toy,
        "title": "Pregunta a la IA",
        "text": "Pide riesgos, oportunidades o acciones.",
      },
      {
        "icon": Icons.share,
        "title": "Guarda y comparte",
        "text": "Exporta PDF o comparte reportes.",
      },
    ];

    return Card(
      color: panelColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined, color: biCyan),
                const SizedBox(width: 8),
                Text(
                  "C?mo funciona",
                  style: TextStyle(
                    color: panelText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(steps.length, (index) {
              final step = steps[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: biYellow.withValues(alpha: 0.18),
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(
                          color: biYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(step["icon"] as IconData, color: softText, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step["title"].toString(),
                            style: TextStyle(
                              color: panelText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            step["text"].toString(),
                            style: TextStyle(color: softText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: biYellow.withValues(alpha: isDark ? 0.28 : 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 18, color: biYellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: softText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: biYellow,
              fontSize: 20,
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
      color: isDark ? const Color.fromARGB(255, 86, 49, 149) : Colors.white,
      elevation: 4,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Archivo")),
            DataColumn(label: Text("Cliente")),
            DataColumn(label: Text("Producto")),
            DataColumn(label: Text("Monto")),
            DataColumn(label: Text("Fecha")),
            DataColumn(label: Text("Mes")),
            DataColumn(label: Text("Categoría")),
            DataColumn(label: Text("Descripción")),
          ],
          rows: tablaFiltrada.map((item) {
            return DataRow(
              cells: [
                DataCell(Text((item["archivo"] ?? "N/A").toString())),
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
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildDashboardChart() {
    if (tipoGrafica == "pastel") return buildPieChart();
    if (tipoGrafica == "dona") return buildPieChart(dona: true);
    if (tipoGrafica == "ranking") return buildRankingChart();
    if (tipoGrafica == "dispersion") return buildScatterChart();
    if (tipoGrafica == "heatmap") return buildHeatmapCard();

    if (tipoGrafica == "combinado") {
      return Column(
        children: [
          buildBarChart(),
          const SizedBox(height: 20),
          buildPieChart(dona: true),
          const SizedBox(height: 20),
          buildRankingChart(),
          const SizedBox(height: 20),
          buildScatterChart(),
          const SizedBox(height: 20),
          buildHeatmapCard(),
        ],
      );
    }

    return buildBarChart();
  }

  String get textoGraficaAutomatica {
    final datos = resumenFiltrado;
    if (datos.isEmpty)
      return "Esta grafica necesita datos para explicar el comportamiento.";

    final total = datos.fold<double>(
      0,
      (sum, item) => sum + _monto(item["total"]),
    );
    Map<String, dynamic> top = datos.first;
    for (final item in datos.skip(1)) {
      if (_monto(item["total"]) > _monto(top["total"])) top = item;
    }
    final topCliente = (top["cliente"] ?? "N/A").toString();
    final pct = total > 0 ? (_monto(top["total"]) / total) * 100 : 0;

    switch (tipoGrafica) {
      case "pastel":
      case "dona":
        return "Esta grafica muestra la participacion de cada cliente. $topCliente concentra ${pct.toStringAsFixed(1)}% del total.";
      case "ranking":
        return "Esta grafica ordena los clientes por valor para saber a quien atender primero.";
      case "dispersion":
        return "Esta grafica ayuda a encontrar montos atipicos que podrian ser errores, fraude o ventas extraordinarias.";
      case "heatmap":
        return "Esta grafica cruza cliente y mes para detectar concentracion, huecos y patrones de compra.";
      case "combinado":
        return "Esta vista combina participacion, ranking, dispersion y heatmap para revisar el negocio desde varios angulos.";
      default:
        return "Esta grafica compara montos por cliente. $topCliente es el principal con ${_money(_monto(top["total"]))}.";
    }
  }

  Widget buildChartInsightCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101827) : const Color(0xFFFFF8D8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: biYellow.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: biYellow),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              textoGraficaAutomatica,
              style: TextStyle(color: panelText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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

    final maxValue = datos
        .map((e) => _monto(e["total"]))
        .reduce((a, b) => a > b ? a : b);

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
              Text(
                cliente,
                style: TextStyle(
                  color: panelText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "\$${total.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Color(0xFF00B7C3),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            getDrawingHorizontalLine: (_) =>
                FlLine(color: softText.withOpacity(0.18), strokeWidth: 1),
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
            if (value != index.toDouble() ||
                index < 0 ||
                index >= datos.length) {
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
      biCyan,
      const Color(0xFFF2C811),
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
                      titleStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
                  Container(
                    width: 12,
                    height: 12,
                    color: colors[i % colors.length],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cliente,
                      style: TextStyle(color: softText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "\$${value.toStringAsFixed(2)}",
                    style: TextStyle(color: panelText),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget buildRankingChart() {
    final datos = List<Map<String, dynamic>>.from(resumenFiltrado)
      ..sort((a, b) => _monto(b["total"]).compareTo(_monto(a["total"])));
    if (datos.isEmpty) return const SizedBox.shrink();

    final topDatos = datos.take(8).toList();
    final maxValue = topDatos.fold<double>(0, (max, item) {
      final value = _monto(item["total"]);
      return value > max ? value : max;
    });

    return Card(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ranking de clientes",
              style: TextStyle(
                color: panelText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ...topDatos.map((item) {
              final cliente = (item["cliente"] ?? "N/A").toString();
              final value = _monto(item["total"]);
              final pct = maxValue <= 0
                  ? 0.0
                  : (value / maxValue).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cliente,
                            style: TextStyle(
                              color: panelText,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(_money(value), style: TextStyle(color: softText)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                        backgroundColor: softText.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          biYellow,
                        ),
                      ),
                    ),
                  ],
                ),
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

    final spots = List.generate(
      meses.length,
      (i) => FlSpot(i.toDouble(), porMes[meses[i]] ?? 0),
    );
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
              color: biCyan,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: biCyan.withOpacity(0.18),
              ),
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
          getTitlesWidget: (value, _) => Text(
            "\$${value.toInt()}",
            style: TextStyle(color: softText, fontSize: 10),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 46,
          interval: 1,
          getTitlesWidget: (value, _) {
            final i = value.toInt();
            if (i < 0 || i >= meses.length || value != i.toDouble())
              return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                meses[i],
                style: TextStyle(color: softText, fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildScatterChart() {
    final datos = tablaFiltrada;
    if (datos.isEmpty) return const SizedBox.shrink();

    final spots = List.generate(
      datos.length,
      (i) => ScatterSpot(i.toDouble(), _monto(datos[i]["monto"])),
    );
    final maxY = datos.fold<double>(
      0,
      (max, item) => _monto(item["monto"]) > max ? _monto(item["monto"]) : max,
    );

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

    final clientes =
        datos.map((e) => (e["cliente"] ?? "N/A").toString()).toSet().toList()
          ..sort();
    final meses =
        datos.map((e) => (e["mes"] ?? "N/A").toString()).toSet().toList()
          ..sort();

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
      return Color.lerp(
        const Color(0xFF102033),
        const Color(0xFFF2C811),
        intensity,
      )!;
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
              Text(
                "Heatmap cliente / mes",
                style: TextStyle(
                  color: panelText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const SizedBox(width: 110),
                  ...meses.map(
                    (mes) => SizedBox(
                      width: 80,
                      child: Text(
                        mes,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: softText, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...clientes.map((cliente) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          cliente,
                          style: TextStyle(color: softText, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...meses.map((mes) {
                        final value = acumulado["$cliente|$mes"] ?? 0;
                        return Container(
                          width: 80,
                          height: 42,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: cellColor(value),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            value == 0 ? "" : "\$${value.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                  color: i == 0 ? biCyan : const Color(0xFFF2C811),
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length)
                    return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      labels[i],
                      style: TextStyle(color: softText, fontSize: 11),
                    ),
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

  Widget buildAutomationSourcesCard() {
    final items = [
      {
        "icon": Icons.email_outlined,
        "title": "Correo",
        "text": "Preparado para recibir adjuntos por webhook.",
      },
      {
        "icon": Icons.chat_bubble_outline,
        "title": "WhatsApp",
        "text": "Listo para conectar con n8n o WhatsApp Cloud API.",
      },
      {
        "icon": Icons.api,
        "title": "API",
        "text": "El backend ya acepta cargas por endpoint /upload.",
      },
    ];

    return Card(
      color: panelColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Entradas automaticas",
              style: TextStyle(
                color: panelText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Base SaaS para recibir documentos desde correo, WhatsApp o integraciones externas.",
              style: TextStyle(color: softText, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(item["icon"] as IconData, color: biYellow),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item["title"].toString(),
                            style: TextStyle(
                              color: panelText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            item["text"].toString(),
                            style: TextStyle(color: softText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget buildFilesTab() {
    return ListView(
      children: [
        buildMiniTutorialCard(),
        const SizedBox(height: 16),
        buildAutomationSourcesCard(),
        const SizedBox(height: 16),
        _mainButton(
          "Subir nuevo archivo",
          Icons.upload_file,
          () => seleccionarArchivo(reemplazar: true),
        ),
        const SizedBox(height: 10),
        _mainButton(
          "Agregar mas archivos",
          Icons.add_to_drive,
          () => seleccionarArchivo(reemplazar: false),
        ),
        const SizedBox(height: 10),
        _mainButton(
          "Comparar archivos",
          Icons.compare_arrows,
          () => seleccionarArchivo(reemplazar: true, comparar: true),
        ),
        const SizedBox(height: 10),
        _mainButton("Generar Dashboard", Icons.auto_graph, analizarDocumento),
        const SizedBox(height: 10),
        _dangerButton("Limpiar datos", Icons.refresh, limpiarDatos),
        const SizedBox(height: 14),
        Text(estadoArchivo, style: TextStyle(color: softText)),
        if (cargando) ...[
          const SizedBox(height: 18),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget buildDashboardTab() {
    if (tabla.isEmpty) {
      return Center(
        child: Text(
          "Sube un archivo para generar el dashboard",
          style: TextStyle(color: softText),
        ),
      );
    }

    return ListView(
      children: [
        buildBusinessHealthCard(),
        const SizedBox(height: 16),
        buildAsesorAutomaticoCard(),
        const SizedBox(height: 16),
        buildBusinessAlertsCard(),
        const SizedBox(height: 16),
        buildFileComparisonCard(),
        const SizedBox(height: 16),
        buildSavePanel(),
        const SizedBox(height: 16),
        buildFiltros(),
        const SizedBox(height: 16),
        buildComparisonPanel(),
        const SizedBox(height: 16),
        buildTipoGrafica(),
        const SizedBox(height: 16),
        buildKPIs(),
        const SizedBox(height: 16),
        buildCalidadDatosCard(),
        const SizedBox(height: 16),
        buildInsightsCard(),
        const SizedBox(height: 16),
        buildChartInsightCard(),
        const SizedBox(height: 16),
        buildDashboardChart(),
        const SizedBox(height: 16),
        buildTablaDetalle(),
        const SizedBox(height: 16),
        _mainButton("Descargar Dashboard", Icons.bar_chart, descargardashboard),
        const SizedBox(height: 10),
        _mainButton("Descargar Excel", Icons.download, descargarexcel),
        const SizedBox(height: 10),
        _mainButton("Descargar PDF", Icons.picture_as_pdf, descargarPdf),
      ],
    );
  }

  Widget buildChatTab() {
    return ListView(children: [buildChatCard()]);
  }

  Widget buildHistoryTab() {
    return ListView(children: [buildHistoryPanel()]);
  }

  Widget buildCalidadDatosCard() {
    if (calidadDatos.isEmpty) return const SizedBox.shrink();

    final advertencias = List<String>.from(calidadDatos["advertencias"] ?? []);

    return Card(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Calidad de datos",
              style: TextStyle(
                color: panelText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Registros: ${calidadDatos["registros"] ?? 0}",
              style: TextStyle(color: panelText),
            ),
            Text(
              "Clientes detectados: ${calidadDatos["clientes_detectados"] ?? 0}",
              style: TextStyle(color: panelText),
            ),
            Text(
              "Monto total: \$${_monto(calidadDatos["monto_total"]).toStringAsFixed(2)}",
              style: TextStyle(color: panelText),
            ),
            const SizedBox(height: 10),
            ...advertencias.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: softText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item, style: TextStyle(color: panelText)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInsightsCard() {
    if (insights.isEmpty) return const SizedBox.shrink();

    return Card(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Insights",
              style: TextStyle(
                color: panelText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...insights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: softText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item, style: TextStyle(color: panelText)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get respuestaVisible {
    return respuestaIA.replaceAll("**", "").replaceAll("###", "").trim();
  }

  Widget _iaQuickChip(String label, String pregunta, IconData icon) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isDark ? Colors.white : const Color(0xFF10172A),
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF10172A),
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: isDark
          ? const Color(0xFF20283A)
          : const Color(0xFFFFF7D6),
      side: BorderSide(color: softText.withValues(alpha: 0.18)),
      onPressed: cargando ? null : () => preguntarRapido(pregunta),
    );
  }

  Widget buildChatCard() {
    final cardColor = isDark ? const Color(0xFF151827) : Colors.white;
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF5F7FB);
    final answerColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    return Card(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandMark(size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Asesor IA",
                        style: TextStyle(
                          color: panelText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Haz preguntas sobre tu reporte o pide una accion.",
                        style: TextStyle(color: softText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "Quejas o sugerencias",
                  icon: Icon(Icons.feedback_outlined, color: panelText),
                  onPressed: enviarFeedback,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: preguntaController,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(color: panelText),
              decoration: InputDecoration(
                hintText: "Pregunta a la IA",
                hintStyle: TextStyle(color: softText),
                filled: true,
                fillColor: inputFill,
                prefixIcon: Icon(Icons.search, color: softText),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: softText.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: softText.withValues(alpha: 0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF00B7C3),
                    width: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _iaQuickChip(
                  "Resumen",
                  "Dame un resumen ejecutivo del reporte",
                  Icons.summarize,
                ),
                _iaQuickChip(
                  "Riesgos",
                  "Que riesgos detectas en estos datos?",
                  Icons.warning_amber,
                ),
                _iaQuickChip(
                  "Oportunidades",
                  "Que oportunidades comerciales hay en este reporte?",
                  Icons.trending_up,
                ),
                _iaQuickChip(
                  "Acciones",
                  "Que acciones concretas recomiendas tomar primero?",
                  Icons.checklist,
                ),
                _iaQuickChip(
                  "Grafica",
                  "Que grafica conviene usar para entender mejor este reporte?",
                  Icons.bar_chart,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2C811),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: cargando ? null : preguntarIA,
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Preguntar"),
              ),
            ),
            const SizedBox(height: 16),
            if (respuestaIA.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: answerColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: softText.withValues(alpha: 0.12)),
                ),
                child: SelectableText(
                  respuestaVisible,
                  style: TextStyle(
                    color: panelText,
                    height: 1.35,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
