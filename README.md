# 🎛️ Agente Creador de Filtros Digitales FIR/IIR

> Trabajo Práctico — Técnicas Digitales III · UTN  
> Sistema experto para diseño automático de filtros digitales y monitoreo de señales médicas en tiempo real.

---

## 📌 Descripción

Este proyecto implementa un **agente experto** que recomienda, diseña y despliega filtros digitales **FIR e IIR** orientados al procesamiento de señales médicas (señal de glucosa/CGM, fs = 10 Hz). El flujo completo va desde la interfaz gráfica en MATLAB hasta la ejecución en un microcontrolador **ESP32** con visualización en tiempo real.

---

## 🧠 Arquitectura del sistema

```
┌──────────────────────────┐        UART / protocolo binario        ┌──────────────────┐
│     GUI MATLAB           │ ─────────────────────────────────────► │   Firmware ESP32 │
│  (motor de reglas FIR/IIR│ ◄───────────── ACK por etapa ──────── │  (PlatformIO /   │
│   diseño + envío UART)   │                                        │   Arduino C++)   │
└──────────────────────────┘                                        └──────────────────┘
         │                                                                   │
         │ stream_esp32.m                                                    │ 8 bytes/muestra
         ▼                                                                   │ [float32 cruda][float32 filtrada]
  ┌─────────────────┐ ◄─────────────────────────────────────────────────────┘
  │ Ventana en vivo │
  │  • Señal cruda  │
  │  • Señal filtrada│
  │  • FFT en vivo  │
  └─────────────────┘
```

---

## 🗂️ Estructura de archivos

| Archivo | Descripción |
|---|---|
| `main_app.m` | GUI principal — motor de recomendación + envío + streaming |
| `recomendar_filtro.m` | Motor de reglas: decide FIR/IIR, estructura, confianza |
| `disenar_filtro.m` | Diseña el filtro real con `designfilt` (coeficientes b/sos) |
| `enviar_cadena_esp32.m` | Protocolo binario UART → ESP32 (0xAA + JSON + floats + CRC16) |
| `stream_esp32.m` | Visualización en tiempo real: señal cruda vs. filtrada + FFT |
| `crc16.m` | CRC16-CCITT-FALSE compatible con el firmware |
| `mostrar_respuesta.m` | Gráficas de magnitud, fase y retardo de grupo |
| `exportar_informe.m` | Exporta informe TXT del filtro diseñado |
| `propiedades_senal.m` | Propiedades de señales médicas/industriales |
| `tabla_arquitecturas.m` | Tabla de restricciones por MCU (RAM/Flash/MIPS) |
| `escenarios_prueba.m` | Casos de prueba del Anexo I (A–J) |

---

## 🚀 Cómo usar

### 1. Requisitos

- MATLAB R2021b o superior (con Signal Processing Toolbox)
- ESP32 conectado por USB con el firmware PlatformIO cargado
- Puerto COM disponible (por defecto `COM4`, configurable en la GUI)

### 2. Lanzar la aplicación

```matlab
main_app
```

### 3. Flujo típico

1. Seleccioná la **opción del TP** (A–J) o configurá manualmente los parámetros.
2. Elegí la **plataforma/MCU** (ESP32, STM32F4, Arduino UNO, ATtiny85).
3. Hacé clic en **"Recomendar"** → el agente activa reglas y muestra FIR/IIR sugerido.
4. Ajustá orden y frecuencia en el editor si lo deseás.
5. Hacé clic en **"Crear filtro recomendado"** → se diseña el filtro y se grafican magnitud/fase.
6. Hacé clic en **"Conectar al microcontrolador"** → envía coeficientes al ESP32 por UART **y abre automáticamente la ventana de monitoreo en vivo**.

---

## 📡 Protocolo de comunicación UART

```
[0xAA][tipo: 0x00 FIR / 0x01 IIR][N uint16 LE][json_len uint16 LE]
[JSON UTF-8 metadata][N floats32 LE][CRC16-CCITT-FALSE uint16 LE]
```

El ESP32 responde con **ACK (0x01 / 0x00)** por cada etapa recibida.

Una vez cargado el filtro, el firmware envía **8 bytes por muestra** de forma continua:

```
[muestra_cruda float32 LE][muestra_filtrada float32 LE]
```

---

## 📊 Ventana de monitoreo en vivo

La función `stream_esp32.m` abre automáticamente una figura con:
- **Subplot superior**: señal cruda del ADC vs. señal filtrada superpuestas en tiempo real.
- **Subplot inferior**: FFT en vivo de ambas señales (ventana de Hann, 128 puntos) con marcadores de frecuencia de corte FIR/IIR.

---

## 🎯 Casos del Anexo I soportados

| Opción | Señal | fs (Hz) | Notas |
|---|---|---|---|
| A | Médica / biomédica | 500 | Fase lineal, pendiente estrecha |
| B | Vibración mecánica | 1000 | — |
| C | Médica / biomédica | 125 | Fase lineal |
| D | Médica / biomédica | 1000 | — |
| E | Industrial lenta | 50 | — |
| F | Industrial lenta | 500 | — |
| G | Industrial lenta | 100 | — |
| H | Corriente eléctrica | 2000 | — |
| I | Control / encoder | 1000 | — |
| **J** | **Médica / CGM glucosa** | **10** | **Caso principal del TP** |

---

## 👨‍💻 Autor

**Marcos Penon** — UTN · Técnicas Digitales III  
📧 penonmarcos@yahoo.com.ar
