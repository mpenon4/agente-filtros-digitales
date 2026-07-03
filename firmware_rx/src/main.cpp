// ═══════════════════════════════════════════════════════════════════════════
// main.cpp — ESP32 Receptor (RX)
// ═══════════════════════════════════════════════════════════════════════════
//
// Recibe muestras crudas (float32) por UART2 desde el ESP32 Emisor (TX),
// aplica la cadena de filtrado FIR pasa-bajos + IIR pasa-altos,
// y retransmite por USB a MATLAB en formato binario (8 bytes/muestra).
//
// Conexión física:
//   GND  Receptor ──── GND  Emisor
//   GPIO16 (RX2) Receptor ◄── GPIO17 (TX2) Emisor
//
// ═══════════════════════════════════════════════════════════════════════════
// DISEÑO DEL FILTRO (generado por el agente MATLAB — Opción J, CGM/SpO2)
//
//   fs = 10 Hz
//   Etapa 1: FIR Lowpass,  orden 200, fc = 0.5 Hz, ventana Hamming, 201 taps
//   Etapa 2: IIR Highpass, orden 2,   fc = 0.01 Hz, Butterworth, 1 sección SOS
//
//   IMPORTANTE: El Emisor (TX) DEBE transmitir a fs = 10 Hz (cada 100 ms)
//   para que las frecuencias de corte sean correctas. Si el TX envía a otra
//   tasa, los filtros quedan desplazados y la salida será incorrecta.
// ═══════════════════════════════════════════════════════════════════════════

#include <Arduino.h>
#include <string.h>

// ── Configuración ─────────────────────────────────────────────────────────
#define PIN_RX2         16      // GPIO de recepción UART2
#define BAUD_UART       115200  // Velocidad de ambos puertos
#define BYTES_POR_FLOAT 4       // sizeof(float) en ESP32

// ── Etapa 1: FIR Pasa-Bajos ──────────────────────────────────────────────
// Orden 200, fc = 0.5 Hz, fs = 10 Hz, ventana Hamming
// 201 coeficientes simétricos (fase lineal garantizada)
#define FIR_N 201

static const float fir_b[FIR_N] = {
    -3.1232583092e-19f, -7.98315738281e-05f, -0.000154699730397f, -0.000218135599692f,
    -0.000264113078917f, -0.000287460768161f, -0.000284313402982f, -0.000252578643879f,
    -0.000192374681266f, -0.000106376690283f,  4.00222137663e-19f,  0.000118651526131f,
     0.000239129814386f,  0.00034931072577f,   0.000436379017058f,  0.000488077656528f,
     0.000494121953346f,  0.000447637035721f,  0.000346447413516f,  0.000194035855617f,
    -6.5530715498e-19f,  -0.000220129195865f, -0.000445784186961f, -0.000652972349992f,
    -0.000816513540439f, -0.000912725758578f, -0.000922302189687f, -0.000833065753675f,
    -0.000642261591516f, -0.000358060497381f,  1.05261138409e-18f,  0.000401817364726f,
     0.000808824047152f,  0.00117729565036f,   0.00146262633618f,   0.00162419180058f,
     0.00163031114289f,   0.00146275545445f,   0.00112024484168f,   0.000620433123765f,
    -1.55324391888e-18f, -0.000687353903924f, -0.00137499805056f,  -0.00198930324305f,
    -0.0024569383159f,   -0.0027128606244f,   -0.00270818890171f,  -0.00241708485747f,
    -0.00184179881878f,  -0.00101515921705f,   2.10819935871e-18f,  0.00111469207661f,
     0.0022207923715f,    0.00320074629861f,   0.00393917134394f,   0.00433528331048f,
     0.00431489856417f,   0.00384070438667f,   0.00291956393991f,   0.00160583296322f,
    -2.66315479855e-18f, -0.00175760541728f,  -0.00349779979538f,  -0.00503748594189f,
    -0.00619733803802f,  -0.00682064617931f,  -0.00679149248017f,  -0.00605035651231f,
    -0.00460536053757f,  -0.00253766560186f,   3.16378733333e-18f,  0.0027920943624f,
     0.00557602635069f,   0.00806395457267f,   0.00996898924911f,   0.0110336260568f,
     0.0110578772267f,    0.00992442184917f,   0.0076182002648f,    0.00423822977858f,
    -3.56109156244e-18f, -0.00477242776414f,  -0.00966460469446f,  -0.0141992176186f,
    -0.017871114902f,    -0.0201872321672f,   -0.0207082490748f,   -0.019088503103f,
    -0.0151106790619f,   -0.00871209509072f,   3.81617657976e-18f,  0.0107458614453f,
     0.0230841377165f,    0.0364358227999f,    0.0501197704389f,    0.0633972620676f,
     0.0755223067344f,    0.0857938067701f,    0.0936054994148f,    0.0984897060146f,
     0.100151380037f,
     0.0984897060146f,    0.0936054994148f,    0.0857938067701f,
     0.0755223067344f,    0.0633972620676f,    0.0501197704389f,    0.0364358227999f,
     0.0230841377165f,    0.0107458614453f,    3.81617657976e-18f, -0.00871209509072f,
    -0.0151106790619f,   -0.019088503103f,    -0.0207082490748f,  -0.0201872321672f,
    -0.017871114902f,    -0.0141992176186f,   -0.00966460469446f, -0.00477242776414f,
    -3.56109156244e-18f,  0.00423822977858f,   0.0076182002648f,   0.00992442184917f,
     0.0110578772267f,    0.0110336260568f,    0.00996898924911f,   0.00806395457267f,
     0.00557602635069f,   0.0027920943624f,    3.16378733333e-18f, -0.00253766560186f,
    -0.00460536053757f,  -0.00605035651231f,  -0.00679149248017f, -0.00682064617931f,
    -0.00619733803802f,  -0.00503748594189f,  -0.00349779979538f, -0.00175760541728f,
    -2.66315479855e-18f,  0.00160583296322f,   0.00291956393991f,  0.00384070438667f,
     0.00431489856417f,   0.00433528331048f,   0.00393917134394f,  0.00320074629861f,
     0.0022207923715f,    0.00111469207661f,   2.10819935871e-18f, -0.00101515921705f,
    -0.00184179881878f,  -0.00241708485747f,  -0.00270818890171f, -0.0027128606244f,
    -0.0024569383159f,   -0.00198930324305f,  -0.00137499805056f, -0.000687353903924f,
    -1.55324391888e-18f,  0.000620433123765f,  0.00112024484168f,  0.00146275545445f,
     0.00163031114289f,   0.00162419180058f,   0.00146262633618f,  0.00117729565036f,
     0.000808824047152f,  0.000401817364726f,  1.05261138409e-18f, -0.000358060497381f,
    -0.000642261591516f, -0.000833065753675f, -0.000922302189687f,-0.000912725758578f,
    -0.000816513540439f, -0.000652972349992f, -0.000445784186961f,-0.000220129195865f,
    -6.5530715498e-19f,   0.000194035855617f,  0.000346447413516f, 0.000447637035721f,
     0.000494121953346f,  0.000488077656528f,  0.000436379017058f, 0.00034931072577f,
     0.000239129814386f,  0.000118651526131f,  4.00222137663e-19f,-0.000106376690283f,
    -0.000192374681266f, -0.000252578643879f, -0.000284313402982f,-0.000287460768161f,
    -0.000264113078917f, -0.000218135599692f, -0.000154699730397f,-7.98315738281e-05f,
    -3.1232583092e-19f
};

// ── Etapa 2: IIR Pasa-Altos (Butterworth, 1 sección SOS) ─────────────────
// Orden 2, fc = 0.01 Hz, fs = 10 Hz
// SOS: [b0 b1 b2 1 a1 a2]  →  Direct Form II Transposed
static const float iir_b0 =  0.995566972018f;
static const float iir_b1 = -1.99113394404f;
static const float iir_b2 =  0.995566972018f;
static const float iir_a1 = -1.9911142922f;   // nota: signo negativo incluido
static const float iir_a2 =  0.991153595869f;  // nota: signo positivo

// ── Variables de estado ───────────────────────────────────────────────────
static float    fir_buf[FIR_N];     // Buffer circular del FIR
static uint16_t fir_idx = 0;        // Índice actual del buffer circular
static float    iir_z1  = 0.0f;     // Estado z^{-1} del IIR (DF2T)
static float    iir_z2  = 0.0f;     // Estado z^{-2} del IIR (DF2T)


// ══════════════════════════════════════════════════════════════════════════
// Filtro FIR Pasa-Bajos (convolución directa con buffer circular)
// y[n] = Σ b[k] · x[n-k],  k = 0..N-1
// ══════════════════════════════════════════════════════════════════════════
float filtrar_fir(float entrada) {
    fir_buf[fir_idx] = entrada;

    float y = 0.0f;
    uint16_t j = fir_idx;

    for (uint16_t k = 0; k < FIR_N; k++) {
        y += fir_b[k] * fir_buf[j];
        if (j == 0) j = FIR_N - 1;
        else        j--;
    }

    fir_idx++;
    if (fir_idx >= FIR_N) fir_idx = 0;

    return y;
}

// ══════════════════════════════════════════════════════════════════════════
// Filtro IIR Pasa-Altos (Direct Form II Transposed — biquad SOS)
//   salida = b0·x + z1
//   z1     = b1·x − a1·salida + z2
//   z2     = b2·x − a2·salida
// ══════════════════════════════════════════════════════════════════════════
float filtrar_iir(float entrada) {
    float salida = iir_b0 * entrada + iir_z1;
    iir_z1 = iir_b1 * entrada - iir_a1 * salida + iir_z2;
    iir_z2 = iir_b2 * entrada - iir_a2 * salida;
    return salida;
}

// ══════════════════════════════════════════════════════════════════════════
// Cadena completa: FIR lowpass → IIR highpass
// ══════════════════════════════════════════════════════════════════════════
float filtrar_cadena(float entrada) {
    float salida_fir = filtrar_fir(entrada);
    float salida_iir = filtrar_iir(salida_fir);
    return salida_iir;
}

// ══════════════════════════════════════════════════════════════════════════
void setup() {
    // Puerto USB → PC (MATLAB lee estos 8 bytes por muestra)
    Serial.begin(BAUD_UART);

    // Puerto UART2 ← Emisor (solo RX en GPIO16, TX deshabilitado)
    Serial2.begin(BAUD_UART, SERIAL_8N1, PIN_RX2, -1);

    // Inicializar todo a cero
    memset(fir_buf, 0, sizeof(fir_buf));
    fir_idx = 0;
    iir_z1  = 0.0f;
    iir_z2  = 0.0f;
}

// ══════════════════════════════════════════════════════════════════════════
void loop() {
    // Esperar hasta tener 4 bytes (un float32 completo)
    if (Serial2.available() < BYTES_POR_FLOAT) {
        delay(1);   // Cede CPU a FreeRTOS
        return;
    }

    // Leer la muestra cruda del emisor
    float muestra_cruda;
    Serial2.readBytes((char*)&muestra_cruda, BYTES_POR_FLOAT);

    // Aplicar cadena de filtrado (FIR lowpass -> IIR highpass)
    float muestra_filtrada = filtrar_cadena(muestra_cruda);

    // Transmitir a MATLAB: 8 bytes binarios [float cruda][float filtrada]
    Serial.write((uint8_t*)&muestra_cruda,    BYTES_POR_FLOAT);
    Serial.write((uint8_t*)&muestra_filtrada, BYTES_POR_FLOAT);
}
