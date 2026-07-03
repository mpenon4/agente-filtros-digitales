// ═══════════════════════════════════════════════════════════════════════════
// main.cpp — ESP32 Transmisor (TX)
// ═══════════════════════════════════════════════════════════════════════════
//
// Lee la señal del ADC (o genera una señal sintética de prueba) y la
// transmite al Receptor por UART2 a exactamente fs = 10 Hz (100 ms).
//
// Conexión física:
//   GND  Transmisor ──── GND  Receptor
//   GPIO17 (TX2) Transmisor ──► GPIO16 (RX2) Receptor
//
// ═══════════════════════════════════════════════════════════════════════════
// IMPORTANTE: La frecuencia de muestreo DEBE ser 10 Hz para que los
// filtros diseñados (FIR fc=0.5 Hz, IIR fc=0.01 Hz) funcionen bien.
// ═══════════════════════════════════════════════════════════════════════════

#include <Arduino.h>

// ── Configuración ─────────────────────────────────────────────────────────
#define PIN_TX2         17          // GPIO de transmisión UART2
#define PIN_ADC         34          // GPIO de entrada analógica (ADC1_CH6)
#define BAUD_UART       115200
#define FS_HZ           10          // Frecuencia de muestreo: 10 Hz
#define PERIODO_MS      (1000 / FS_HZ)  // = 100 ms

// Si USAR_ADC_REAL es true, lee del ADC real.
// Si es false, genera una señal sintética para pruebas sin hardware.
#define USAR_ADC_REAL   false

// ── Variables ─────────────────────────────────────────────────────────────
unsigned long ultimo_envio = 0;

// ══════════════════════════════════════════════════════════════════════════
// Genera una señal sintética de prueba para verificar el filtro
// sin necesidad de conectar un sensor real.
//
// Componentes:
//   - Offset DC de -128 V (simula el offset del sensor real)
//   - Señal útil lenta: senoide a 0.2 Hz (simula respiración)
//   - Ruido de alta frecuencia (debe ser eliminado por el FIR)
// ══════════════════════════════════════════════════════════════════════════
float generar_senal_sintetica(float t_seg) {
    float offset_dc   = -128.0f;
    float senal_util   = 1.5f * sin(2.0f * PI * 0.2f * t_seg);   // 0.2 Hz
    float ruido_rapido = ((float)random(-100, 100) / 100.0f) * 0.3f;

    return offset_dc + senal_util + ruido_rapido;
}

// ══════════════════════════════════════════════════════════════════════════
// Lee una muestra real del ADC y la convierte a voltaje
// ══════════════════════════════════════════════════════════════════════════
float leer_adc_real() {
    int lectura_adc = analogRead(PIN_ADC);
    // ESP32 ADC: 12 bits (0–4095), rango 0–3.3 V por defecto
    float voltaje = (float)lectura_adc * (3.3f / 4095.0f);
    return voltaje;
}

// ══════════════════════════════════════════════════════════════════════════
void setup() {
    Serial.begin(BAUD_UART);

    // UART2: solo TX en GPIO17, RX deshabilitado
    Serial2.begin(BAUD_UART, SERIAL_8N1, -1, PIN_TX2);

    if (USAR_ADC_REAL) {
        analogReadResolution(12);
        analogSetAttenuation(ADC_11db);  // Rango completo 0–3.3 V
    } else {
        randomSeed(analogRead(0));
    }

    Serial.println("ESP32 TX inicializado — fs = 10 Hz");
    ultimo_envio = millis();
}

// ══════════════════════════════════════════════════════════════════════════
void loop() {
    unsigned long ahora = millis();

    if (ahora - ultimo_envio >= PERIODO_MS) {
        ultimo_envio += PERIODO_MS;  // Mantiene timing preciso sin drift

        float muestra;

        if (USAR_ADC_REAL) {
            muestra = leer_adc_real();
        } else {
            float t = (float)ahora / 1000.0f;
            muestra = generar_senal_sintetica(t);
        }

        // Transmitir 4 bytes binarios (float32 little-endian) al Receptor
        Serial2.write((uint8_t*)&muestra, sizeof(float));
    }
}
