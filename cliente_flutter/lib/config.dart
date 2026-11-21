/// URL base de la API. Se puede cambiar al compilar: --dart-define=API_URL=https://mi-api.onrender.com
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://aerotech-api-bbql.onrender.com');

/// Tiempo máximo de espera de cada llamada (el plan gratuito de Render puede tardar hasta 1 minuto en despertar).
const Duration tiempoEspera = Duration(seconds: 60);

/// Pasado este tiempo se avisa al usuario que se está conectando con el servidor.
const Duration umbralConexionLenta = Duration(seconds: 5);

const double ivaPorcentaje = 15;
