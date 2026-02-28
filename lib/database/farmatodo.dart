import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class FarmatodoDB {
  static Database? _db;
  static const int _version = 4;

  /// Obtiene o crea la base de datos
  static Future<Database> getDB() async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  /// Inicializa la base de datos SQLite
  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'farmatodo.db');

    return await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        print('🆕 Creando base de datos versión $version');
        await _crearTablas(db);
        await _crearAdminPorDefecto(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('🔄 Actualizando BD de $oldVersion a $newVersion');
        await _recrearTablas(db);
      },
    );
  }

  /// Crea todas las tablas necesarias
  static Future<void> _crearTablas(Database db) async {
    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        correo TEXT UNIQUE,
        password TEXT,
        rol TEXT
      )
    ''');

    // Tabla de medicamentos
    await db.execute('''
      CREATE TABLE medicamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        codigo_barras TEXT,
        lote TEXT,
        fecha_vencimiento TEXT NOT NULL,
        fecha_creacion TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    print('✅ Tablas usuarios y medicamentos creadas correctamente');
  }

  /// Recrea las tablas (para upgrades)
  static Future<void> _recrearTablas(Database db) async {
    try {
      await db.execute('DROP TABLE IF EXISTS usuarios');
      await db.execute('DROP TABLE IF EXISTS medicamentos');
      await _crearTablas(db);
      await _crearAdminPorDefecto(db);
      print('✅ Tablas recreadas correctamente');
    } catch (e) {
      print('❌ Error recreando tablas: $e');
      rethrow;
    }
  }

  /// Crea el usuario admin por defecto
  static Future<void> _crearAdminPorDefecto(Database db) async {
    try {
      await db.insert('usuarios', {
        'nombre': 'Administrador',
        'correo': 'admin@farmatodo.com',
        'password': 'admin123',
        'rol': 'admin',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      print('✅ Usuario admin creado por defecto');
    } catch (e) {
      print('❌ Error creando usuario admin: $e');
    }
  }

  // ============================================================
  // ===============        USUARIOS        =====================
  // ============================================================

  /// Inserta un nuevo usuario
  static Future<int> insertarUsuario({
    required String nombre,
    required String correo,
    required String password,
    required String rol,
  }) async {
    try {
      final db = await getDB();
      final id = await db.insert('usuarios', {
        'nombre': nombre,
        'correo': correo,
        'password': password,
        'rol': rol,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      print('✅ Usuario insertado con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error insertando usuario: $e');
      rethrow;
    }
  }

  /// Obtiene todos los usuarios
  static Future<List<Map<String, dynamic>>> obtenerUsuarios() async {
    try {
      final db = await getDB();
      final usuarios = await db.query('usuarios', orderBy: 'id DESC');
      print('✅ Usuarios obtenidos: ${usuarios.length}');
      return usuarios;
    } catch (e) {
      print('❌ Error obteniendo usuarios: $e');
      return [];
    }
  }

  /// Elimina un usuario por ID
  static Future<int> eliminarUsuario(int id) async {
    try {
      final db = await getDB();
      final count = await db.delete(
        'usuarios',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Usuario eliminado: $count filas afectadas');
      return count;
    } catch (e) {
      print('❌ Error eliminando usuario: $e');
      rethrow;
    }
  }

  /// Verifica el login del usuario (correo y contraseña)
  static Future<Map<String, dynamic>?> loginUsuario(
    String correo,
    String password,
  ) async {
    try {
      final db = await getDB();
      final res = await db.query(
        'usuarios',
        where: 'correo = ? AND password = ?',
        whereArgs: [correo, password],
      );
      if (res.isNotEmpty) {
        print('✅ Login exitoso para: $correo');
        return res.first;
      } else {
        print('❌ Login fallido para: $correo');
        return null;
      }
    } catch (e) {
      print('❌ Error en login: $e');
      return null;
    }
  }

  /// Actualiza un usuario existente
  static Future<int> actualizarUsuario({
    required int id,
    required String nombre,
    required String correo,
    required String password,
  }) async {
    try {
      final db = await getDB();
      final count = await db.update(
        'usuarios',
        {'nombre': nombre, 'correo': correo, 'password': password},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Usuario actualizado: $count filas afectadas');
      return count;
    } catch (e) {
      print('❌ Error actualizando usuario: $e');
      rethrow;
    }
  }

  // ============================================================
  // ===============       MEDICAMENTOS       ===================
  // ============================================================

  /// Inserta un nuevo medicamento
  static Future<int> insertarMedicamento({
    required String nombre,
    required String descripcion,
    required String codigoBarras,
    required String lote,
    required DateTime fechaVencimiento,
  }) async {
    try {
      final db = await getDB();
      final id = await db.insert('medicamentos', {
        'nombre': nombre,
        'descripcion': descripcion,
        'codigo_barras': codigoBarras,
        'lote': lote,
        'fecha_vencimiento': fechaVencimiento.toIso8601String(),
      });
      print('✅ Medicamento insertado con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error insertando medicamento: $e');
      rethrow;
    }
  }

  /// Obtiene todos los medicamentos
  static Future<List<Map<String, dynamic>>> obtenerMedicamentos() async {
    try {
      final db = await getDB();
      final medicamentos = await db.query(
        'medicamentos',
        orderBy: 'fecha_vencimiento ASC',
      );
      print('✅ Medicamentos obtenidos: ${medicamentos.length}');
      return medicamentos;
    } catch (e) {
      print('❌ Error obteniendo medicamentos: $e');
      return [];
    }
  }

  /// Obtiene medicamentos próximos a vencer (30 días o menos)
  static Future<List<Map<String, dynamic>>>
  obtenerMedicamentosProximosAVencer() async {
    try {
      final db = await getDB();
      final hoy = DateTime.now();
      final limite = hoy.add(const Duration(days: 30));

      final medicamentos = await db.rawQuery(
        '''
        SELECT * FROM medicamentos 
        WHERE fecha_vencimiento BETWEEN ? AND ?
        ORDER BY fecha_vencimiento ASC
      ''',
        [hoy.toIso8601String(), limite.toIso8601String()],
      );

      print('✅ Medicamentos próximos a vencer: ${medicamentos.length}');
      return medicamentos;
    } catch (e) {
      print('❌ Error obteniendo medicamentos próximos a vencer: $e');
      return [];
    }
  }

  /// Obtiene medicamentos vencidos
  static Future<List<Map<String, dynamic>>>
  obtenerMedicamentosVencidos() async {
    try {
      final db = await getDB();
      final hoy = DateTime.now();

      final medicamentos = await db.rawQuery(
        '''
        SELECT * FROM medicamentos 
        WHERE fecha_vencimiento < ?
        ORDER BY fecha_vencimiento ASC
      ''',
        [hoy.toIso8601String()],
      );

      print('✅ Medicamentos vencidos: ${medicamentos.length}');
      return medicamentos;
    } catch (e) {
      print('❌ Error obteniendo medicamentos vencidos: $e');
      return [];
    }
  }

  /// Elimina un medicamento por ID
  static Future<int> eliminarMedicamento(int id) async {
    try {
      final db = await getDB();
      final count = await db.delete(
        'medicamentos',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Medicamento eliminado: $count filas afectadas');
      return count;
    } catch (e) {
      print('❌ Error eliminando medicamento: $e');
      rethrow;
    }
  }

  /// Actualiza un medicamento existente (método con parámetros individuales)
  static Future<int> actualizarMedicamento({
    required int id,
    required String nombre,
    required String descripcion,
    required String codigoBarras,
    required String lote,
    required DateTime fechaVencimiento,
  }) async {
    try {
      final db = await getDB();
      final count = await db.update(
        'medicamentos',
        {
          'nombre': nombre,
          'descripcion': descripcion,
          'codigo_barras': codigoBarras,
          'lote': lote,
          'fecha_vencimiento': fechaVencimiento.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Medicamento actualizado: $count filas afectadas');
      return count;
    } catch (e) {
      print('❌ Error actualizando medicamento: $e');
      rethrow;
    }
  }

  /// Actualiza un medicamento existente usando objeto Medicamento (NUEVO MÉTODO)
  static Future<int> actualizarMedicamentoObjeto(
    Medicamento medicamento,
  ) async {
    try {
      final db = await getDB();
      final count = await db.update(
        'medicamentos',
        medicamento.toMap(),
        where: 'id = ?',
        whereArgs: [medicamento.id],
      );
      print('✅ Medicamento actualizado: $count filas afectadas');
      return count;
    } catch (e) {
      print('❌ Error actualizando medicamento: $e');
      rethrow;
    }
  }

  /// Busca medicamentos por nombre
  static Future<List<Map<String, dynamic>>> buscarMedicamentos(
    String query,
  ) async {
    try {
      final db = await getDB();
      final medicamentos = await db.rawQuery(
        '''
        SELECT * FROM medicamentos 
        WHERE nombre LIKE ? OR descripcion LIKE ? OR lote LIKE ?
        ORDER BY nombre ASC
      ''',
        ['%$query%', '%$query%', '%$query%'],
      );

      print('✅ Medicamentos encontrados: ${medicamentos.length}');
      return medicamentos;
    } catch (e) {
      print('❌ Error buscando medicamentos: $e');
      return [];
    }
  }

  // ============================================================
  // ===============      VERIFICACIÓN       ====================
  // ============================================================

  /// Verifica si existe la tabla medicamentos
  static Future<bool> verificarTablaMedicamentos() async {
    try {
      final db = await getDB();
      final resultado = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='medicamentos'",
      );
      final existe = resultado.isNotEmpty;
      print('📋 Tabla medicamentos existe: $existe');
      return existe;
    } catch (e) {
      print('❌ Error verificando tabla: $e');
      return false;
    }
  }

  /// Obtiene información detallada de la tabla medicamentos
  static Future<List<Map<String, dynamic>>>
  obtenerInfoTablaMedicamentos() async {
    try {
      final db = await getDB();
      final info = await db.rawQuery("PRAGMA table_info(medicamentos)");
      print('📊 Estructura tabla medicamentos:');
      for (var columna in info) {
        print('  - ${columna['name']} (${columna['type']})');
      }
      return info;
    } catch (e) {
      print('❌ Error obteniendo info de tabla: $e');
      return [];
    }
  }

  /// Cuenta los medicamentos en la base de datos
  static Future<int> contarMedicamentos() async {
    try {
      final db = await getDB();
      final count =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM medicamentos'),
          ) ??
          0;
      print('🔢 Total medicamentos en BD: $count');
      return count;
    } catch (e) {
      print('❌ Error contando medicamentos: $e');
      return 0;
    }
  }

  /// Obtiene todos los medicamentos con información detallada
  static Future<List<Map<String, dynamic>>>
  obtenerMedicamentosDetallados() async {
    try {
      final db = await getDB();
      final medicamentos = await db.query('medicamentos', orderBy: 'id DESC');

      print('📦 Medicamentos en BD: ${medicamentos.length}');
      return medicamentos;
    } catch (e) {
      print('❌ Error obteniendo medicamentos detallados: $e');
      return [];
    }
  }

  // ============================================================
  // ===============      MÉTODOS GENERALES      ================
  // ============================================================

  /// Verifica el estado de la base de datos
  static Future<bool> verificarEstado() async {
    try {
      final db = await getDB();
      await db.rawQuery('SELECT 1');
      print('✅ Base de datos funcionando correctamente');
      return true;
    } catch (e) {
      print('❌ Error verificando estado de BD: $e');
      return false;
    }
  }

  /// Obtiene estadísticas de la base de datos
  static Future<Map<String, int>> obtenerEstadisticas() async {
    try {
      final db = await getDB();

      final usuariosCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM usuarios'),
          ) ??
          0;

      final medicamentosCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM medicamentos'),
          ) ??
          0;

      final proximosVencerCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              '''
          SELECT COUNT(*) FROM medicamentos 
          WHERE fecha_vencimiento BETWEEN ? AND ?
        ''',
              [
                DateTime.now().toIso8601String(),
                DateTime.now().add(const Duration(days: 30)).toIso8601String(),
              ],
            ),
          ) ??
          0;

      final vencidosCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              '''
          SELECT COUNT(*) FROM medicamentos 
          WHERE fecha_vencimiento < ?
        ''',
              [DateTime.now().toIso8601String()],
            ),
          ) ??
          0;

      print(
        '📊 Estadísticas - Usuarios: $usuariosCount, Medicamentos: $medicamentosCount',
      );
      return {
        'usuarios': usuariosCount,
        'medicamentos': medicamentosCount,
        'proximos_vencer': proximosVencerCount,
        'vencidos': vencidosCount,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {
        'usuarios': 0,
        'medicamentos': 0,
        'proximos_vencer': 0,
        'vencidos': 0,
      };
    }
  }

  /// Método para inicializar y verificar la base de datos
  static Future<void> inicializarBD() async {
    try {
      final db = await getDB();
      // Verificar que las tablas existen
      final tablas = await db.rawQuery("""
        SELECT name FROM sqlite_master 
        WHERE type='table' AND (name='usuarios' OR name='medicamentos')
      """);

      if (tablas.length < 2) {
        print('⚠️  Tablas faltantes, recreando...');
        await _recrearTablas(db);
      }

      print('✅ Base de datos inicializada correctamente');
    } catch (e) {
      print('❌ Error inicializando BD: $e');
      rethrow;
    }
  }

  /// Cierra la base de datos
  static Future<void> closeDB() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      print('🔒 Base de datos cerrada');
    }
  }
}

class Medicamento {
  final int? id;
  final String nombre;
  final String descripcion;
  final String codigoBarras;
  final String lote;
  final DateTime fechaVencimiento;

  Medicamento({
    this.id,
    required this.nombre,
    required this.descripcion,
    required this.codigoBarras,
    required this.lote,
    required this.fechaVencimiento,
  });

  factory Medicamento.fromMap(Map<String, dynamic> map) {
    return Medicamento(
      id: map['id'],
      nombre: map['nombre'],
      descripcion: map['descripcion'] ?? '',
      codigoBarras: map['codigo_barras'] ?? '',
      lote: map['lote'] ?? '',
      fechaVencimiento: DateTime.parse(map['fecha_vencimiento']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'codigo_barras': codigoBarras,
      'lote': lote,
      'fecha_vencimiento': fechaVencimiento.toIso8601String(),
    };
  }
}
