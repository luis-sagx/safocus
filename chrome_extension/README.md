# SaFocus Chrome Extension

Bloquea sitios web distractores directamente desde Chrome — sin instalar nada adicional.

## Características

- **Sesión de Enfoque**: activa un temporizador de X minutos durante el cual todas las distracciones quedan bloqueadas.
- **Bloqueo de sitios predefinidos**: redes sociales, contenido adulto, streaming, apuestas y más.
- **Sitios personalizados**: agrega y administra tus propios dominios bloqueados.
- **Pantalla de redirección**: página de bloqueo motivacional con frases inspiradoras.
- **Estadísticas semanales**: histograma de bloqueos por día, total de sesiones y minutos enfocados.
- **Funciona offline**: usa `declarativeNetRequest` — sin servidores externos.

## Instalación (modo desarrollador)

1. Abre Chrome y ve a `chrome://extensions/`
2. Activa **Modo desarrollador** (esquina superior derecha)
3. Haz clic en **Cargar descomprimida** y selecciona la carpeta `chrome_extension/`
4. La extensión aparecerá en la barra de Chrome

> **Nota:** Los íconos (icons/icon16.png, icon48.png, icon128.png) deben ser imágenes PNG reales.
> Puedes exportarlas desde cualquier editor o usar los SVG de referencia como plantilla.

## Estructura de archivos

```
chrome_extension/
├── manifest.json         ← MV3 manifest
├── background.js         ← Service worker: sesiones, reglas DNR, stats
├── blocked.html/css/js   ← Página de bloqueo personalizada
├── popup.html/css/js     ← Popup de la extensión
├── rules/
│   ├── default_block_rules.json   ← 15 dominios predefinidos
│   └── user_block_rules.json      ← Reglas de usuario (vacío inicial)
└── icons/
    ├── icon16.png
    ├── icon48.png
    └── icon128.png
```

## Permisos utilizados

| Permiso                 | Motivo                                                 |
| ----------------------- | ------------------------------------------------------ |
| `declarativeNetRequest` | Bloquear dominios sin leer el contenido de las páginas |
| `storage`               | Guardar lista de sitios, stats y sesión activa         |
| `alarms`                | Temporizador de sesión de enfoque                      |
| `notifications`         | Alertas de inicio/fin de sesión                        |
| `webNavigation`         | Contabilizar intentos de acceso bloqueados             |
| `tabs`                  | Abrir nueva pestaña desde la página de bloqueo         |

## Tecnologías

- HTML + CSS + JavaScript puro (sin frameworks)
- Manifest V3
- `declarativeNetRequest` API (más eficiente y segura que `webRequest`)
