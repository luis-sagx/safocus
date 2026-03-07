# SaFocus — Manual de Uso

**Versión 1.0** · Aplicación Android anti-procrastinación

---

## Tabla de contenido

1. [Primeros pasos](#1-primeros-pasos)
2. [Pantalla de Inicio](#2-pantalla-de-inicio)
3. [Bloqueo de sitios web](#3-bloqueo-de-sitios-web)
4. [Límites de aplicaciones](#4-límites-de-aplicaciones)
5. [Notificaciones motivacionales](#5-notificaciones-motivacionales)
6. [Estadísticas](#6-estadísticas)
7. [Configuración](#7-configuración)
8. [Permisos necesarios](#8-permisos-necesarios)
9. [Preguntas frecuentes](#9-preguntas-frecuentes)

---

## 1. Primeros pasos

Al abrir SaFocus por primera vez verás la pantalla de **bienvenida** con tres diapositivas que explican las funciones principales:

| Diapositiva                         | Descripción                                                              |
| ----------------------------------- | ------------------------------------------------------------------------ |
| **Bloquea las distracciones**       | Activa el escudo VPN para impedir el acceso a sitios distractores.       |
| **Controla el tiempo en apps**      | Establece límites diarios para las aplicaciones que más tiempo consumen. |
| **Construye el hábito del enfoque** | Recordatorios motivacionales, racha de días y puntaje de enfoque diario. |

Toca **Siguiente** para avanzar o **Omitir** para ir directamente a la pantalla principal.

> La pantalla de bienvenida aparece sólo la primera vez. Puedes reiniciarla desde **Ajustes → Restablecer datos**.

---

## 2. Pantalla de Inicio

La pantalla principal resume tu estado de enfoque del día.

### Puntaje de enfoque

Un círculo de progreso grande muestra tu **puntaje del día (0-100)**. Se calcula en función de:

- Porcentaje del tiempo en que el VPN estuvo activo.
- Número de intentos de acceso bloqueados.
- Uso de apps por debajo de los límites establecidos.

| Rango  | Etiqueta          |
| ------ | ----------------- |
| 80-100 | Excelente         |
| 60-79  | Muy bien          |
| 40-59  | Regular           |
| 0-39   | Necesitas mejorar |

### Tarjetas de estado

- **Escudo VPN** — muestra si el bloqueo de sitios está activo y cuántos sitios están protegidos.
- **Límites activos** — número de aplicaciones con límite configurado hoy.

### Métricas rápidas

- **Racha** — días consecutivos con puntaje ≥ 50.
- **Bloqueos hoy** — intentos de acceso a sitios bloqueados durante el día.

### Lista de límites

Debajo de las métricas aparecen las aplicaciones con límite activo y su barra de progreso de uso diario.

---

## 3. Bloqueo de sitios web

Ve a la pestaña **Bloqueo** (ícono de escudo).

### Activar/desactivar el VPN

El interruptor grande en la parte superior activa o desactiva el servicio VPN de SaFocus.

> **¿Qué es el VPN de SaFocus?**
> No es un VPN de red externo. Es un túnel local en el dispositivo que intercepta las consultas DNS y bloquea los dominios de tu lista, sin enviar datos a ningún servidor.

La primera vez que activas el VPN, Android mostrará un diálogo solicitando permiso. Toca **Aceptar** para continuar.

### Sitios personalizados

En la pestaña **Mis sitios** puedes:

- Agregar un dominio manualmente con el botón **➕** (p. ej. `reddit.com`).
- Activar o desactivar cada sitio con su interruptor.
- Eliminar un sitio deslizando hacia la izquierda o tocando el ícono de eliminar.

### Sitios predefinidos

La pestaña **Predefinidos** muestra categorías de sitios bloqueados por defecto:

| Categoría          | Ejemplos                                 |
| ------------------ | ---------------------------------------- |
| Adulto             | pornhub.com, xvideos.com…                |
| Redes sociales     | facebook.com, instagram.com, tiktok.com… |
| Video/streaming    | youtube.com, netflix.com, twitch.tv…     |
| Apuestas/juegos    | bet365.com, pokerstars.com…              |
| Noticias/clickbait | buzzfeed.com, infobae.com…               |

Puedes activar o desactivar una categoría completa con su interruptor.

---

## 4. Límites de aplicaciones

Ve a la pestaña **Límites** (accesible desde el menú lateral o desde Inicio).

### Requisito de permisos

Para leer el tiempo de uso de cada app, SaFocus necesita el permiso **Uso de datos de aplicaciones** (Usage Stats). Si no lo has concedido, la app te llevará automáticamente a la pantalla de ajustes del sistema.

Pasos:

1. Toca el botón "Conceder permiso".
2. En la lista del sistema busca **SaFocus**.
3. Activa **Permitir seguimiento de uso**.

### Agregar un límite

1. Toca el botón **➕** en la esquina inferior derecha.
2. Ingresa el **nombre de la app** como aparece en tu dispositivo.
3. Ingresa el **nombre del paquete** (p. ej. `com.instagram.android`).
4. Selecciona la duración máxima diaria con los chips rápidos (15 min, 30 min, 1 h, 2 h) o escríbela manualmente.
5. Toca **Guardar**.

### Tarjeta de límite

Cada límite muestra:

- Avatar con la inicial de la app.
- Barra de progreso de uso (verde → naranja → rojo según el porcentaje consumido).
- Minutos usados / minutos permitidos.

Cuando el límite se supera la barra se vuelve roja y aparece el botón **Extensión de emergencia** (+5 min, una vez por día).

### Menú de opciones

Toca los tres puntos de una tarjeta para **editar** o **eliminar** el límite.

---

## 5. Notificaciones motivacionales

Ve a la pestaña **Notificaciones**.

### Activar recordatorios

El interruptor en la parte superior activa o desactiva el envío de notificaciones motivacionales.

### Frecuencia

Selecciona cada cuántas horas recibirás una notificación (opciones: 1 h, 2 h, 4 h, 8 h). Las notificaciones respetan las **horas de silencio** configuradas en Ajustes.

### Frases motivacionales

La lista muestra todas las frases disponibles (predefinidas en 🇪🇸 español e 🇬🇧 inglés). Puedes:

- **Activar/desactivar** cada frase con su interruptor.
- **Agregar** una frase propia tocando **➕** (eliges el idioma: ES/EN).
- **Eliminar** frases personalizadas (las predefinidas no se pueden eliminar).

---

## 6. Estadísticas

Ve a la pestaña **Estadísticas**.

### Resumen del día

- **Puntaje de enfoque** — igual al mostrado en Inicio.
- **Racha** — días consecutivos con puntaje ≥ 50.

### Gráfico semanal

Un gráfico de barras muestra el tiempo de uso total en minutos de los últimos 7 días. Toca una barra para ver el detalle del día.

### Bloqueos de la semana

Número total de intentos de acceder a sitios bloqueados durante los últimos 7 días.

### Uso por aplicación

Barra horizontal para cada app con límite activo que muestra cuántos minutos se usó hoy comparado con el límite. Se muestran las 8 apps con mayor uso.

---

## 7. Configuración

Ve a la pestaña **Ajustes**.

### Apariencia

| Opción | Descripción                                              |
| ------ | -------------------------------------------------------- |
| Tema   | Oscuro / Claro / Sistema (sigue el tema del dispositivo) |
| Idioma | Español / English                                        |

### Seguridad

| Opción          | Descripción                                                                         |
| --------------- | ----------------------------------------------------------------------------------- |
| Bloqueo con PIN | Protege SaFocus con un PIN de 4 dígitos para evitar desactivar el escudo fácilmente |
| Biométrico      | Usa huella o Face ID en lugar del PIN (requiere PIN configurado)                    |

Al activar el PIN se mostrará un diálogo para crear uno. Recuérdalo — por ahora no hay recuperación automática.

### Horas de silencio

Define un intervalo en el que **no** se enviarán notificaciones motivacionales. Por ejemplo: 22:00 – 07:00 para no ser molestado de noche.

Toca la hora de inicio o fin para cambiarla con un selector de horas.

### Datos

- **Restablecer todos los datos** — elimina sitios personalizados, límites, frases propias y estadísticas. Requiere confirmación.

---

## 8. Permisos necesarios

| Permiso                                | Por qué se necesita                                    | Cómo concederlo                                                           |
| -------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------- |
| **VPN**                                | Para el escudo de bloqueo DNS                          | Se solicita al activar el escudo por primera vez                          |
| **Uso de datos de apps** (Usage Stats) | Para leer el tiempo de uso de cada aplicación          | Ajustes del sistema → Apps → Acceso a uso de datos                        |
| **Notificaciones** (Android 13+)       | Para enviar recordatorios motivacionales               | Se solicita la primera vez que activas las notificaciones                 |
| **Biométrico**                         | Para el desbloqueo con huella/face                     | Se solicita al activar la opción en Ajustes                               |
| **Inicio automático** (opcional)       | Para reiniciar el VPN tras un reinicio del dispositivo | Según la marca del dispositivo puede requerirse en ajustes del fabricante |

---

## 9. Preguntas frecuentes

**¿El VPN de SaFocus envía mi tráfico a servidores externos?**
No. El servicio VPN de SaFocus funciona completamente en el dispositivo. Crea un túnel local (TUN) que sólo intercepta consultas DNS para bloquear dominios. No hay un servidor VPN remoto.

**¿Por qué YouTube/Instagram siguen cargando si están en la lista de bloqueados?**
El DNS puede estar en caché en el dispositivo o la app puede usar HTTPS DNS (DoH). Asegúrate de que el escudo esté activo (color indigo en el botón) y reinicia la app. Si el problema persiste, considera desinstalar y reinstalar la app bloqueada para limpiar su caché DNS.

**¿Puedo desactivar el bloqueo temporalmente?**
Sí, desactiva el interruptor principal en la pestaña **Bloqueo**. Si tienes PIN activado, se te pedirá que lo ingreses primero.

**¿Qué pasa si supero el límite de una app?**
La app seguirá funcionando (SaFocus no la cierra forzosamente en v1.0). Recibirás una notificación de alerta y en la tarjeta de límite aparecerá el botón de extensión de emergencia (+5 min).

**¿Cómo se calcula el puntaje de enfoque?**

```
puntaje = vpnBonus + blockBonus + limitBonus

vpnBonus   = vpnActivo ? 40 : 0
blockBonus = min(30, intentosBloqueados × 3)
limitBonus = min(30, appsNoPasadas / totalApps × 30)
```

El máximo es 100 puntos.

**¿Puedo usar SaFocus en iOS?**
La funcionalidad de bloqueo VPN y lectura de uso de apps requiere APIs nativas de Android. iOS tiene limitaciones del sistema que impiden implementar el mismo comportamiento en v1.0.

**¿Cómo agrego la extensión de Chrome?**
La extensión está en la carpeta `chrome_extension/` del repositorio. Ver `chrome_extension/README.md` para instrucciones de instalación en modo desarrollador.

---

_SaFocus v1.0.0 · Hecho con Flutter · Para uso personal_
