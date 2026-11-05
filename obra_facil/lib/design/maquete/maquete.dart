/// A maquete 3D da obra (design system Prancheta, seção 7).
///
/// ```dart
/// MaqueteObra(progresso: ProgressoMaquete.doCronograma(cronograma))
/// ```
library;

export 'diagnostico_maquete.dart'
    show DiagnosticoMaquete, ModoMaquete, MotivoMaquete;
export 'fonte_maquete.dart' show FonteMaquete, FontePadrao, FontePlanta;
export 'maquete_obra.dart' show MaqueteObra;
export 'planta_desenhada.dart' show MapaPlanta, PlantaDesenhada;
export 'medidor_quadros.dart' show EstatisticaQuadros;
export 'progresso_maquete.dart' show ProgressoMaquete;
