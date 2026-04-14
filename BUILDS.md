# Documentación de Builds - CTH Mobile

**Fecha:** 14 de abril de 2026

## Resumen

Se han compilado exitosamente tres versiones de la aplicación `cth-mobile` con las últimas mejoras implementadas.

---

## 📱 Build para Android (APK)

### Información
- **Archivo:** `app-release.apk`
- **Ruta:** `build/app/outputs/flutter-apk/app-release.apk`
- **Tamaño:** 50 MB
- **Tipo:** Release Build
- **Hash:** Disponible en `app-release.apk.sha1`

### Uso
- Instalar directamente en dispositivos Android
- Distribuir a través de Google Play Store
- Enviar a usuarios para testing

### Fecha de compilación
14 de abril de 2026

---

## 🐧 Build para Linux

### Información
- **Ejecutable:** `cth_mobile`
- **Ruta:** `build/linux/x64/release/bundle/`
- **Tipo:** Release Build ejecutable
- **Arquitectura:** x64

### Estructura
```
build/linux/x64/release/bundle/
├── cth_mobile         (ejecutable principal)
├── lib/              (librerías compartidas)
└── data/             (recursos de aplicación)
```

### Uso
- Ejecutar desde línea de comandos: `./cth_mobile`
- Distribuir como aplicación Linux
- Puede ser empaquetado en .deb, .rpm, etc.

### Fecha de compilación
14 de abril de 2026

---

## 🌐 Build para Web

### Información
- **Ruta:** `build/web/`
- **Tipo:** Release Build web
- **Base href:** `/mobile/`
- **Tamaño total:** ~3.2 MB

### Archivos principales
- **index.html** - Punto de entrada
- **main.dart.js** - Código compilado (3.1 MB)
- **flutter.js** - Runtime de Flutter
- **flutter_bootstrap.js** - Bootstrap del proyecto
- **flutter_service_worker.js** - Service Worker para offline
- **canvaskit/** - Motor de renderizado CanvasKit
- **assets/** - Recursos de la aplicación (imágenes, fuentes, etc.)
- **icons/** - Iconos de la aplicación
- **manifest.json** - Manifest de PWA

### Configuración de despliegue

Para desplegar en un servidor web alojado en la carpeta `/mobile/`:

1. **Copiar contenido:** Copiar todos los archivos de `build/web/` a la carpeta `/mobile/` del servidor
2. **Servidor web:** Configurar el servidor para servir archivos estáticos
3. **Reescritura de URL:** Configurar reescritura de URL para que todas las rutas no encontradas apunten a `index.html`

### Ejemplo de configuración (Apache)
```apache
<Directory /var/www/html/mobile>
    <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteBase /mobile/
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /mobile/index.html [L]
    </IfModule>
</Directory>
```

### Ejemplo de configuración (Nginx)
```nginx
location /mobile/ {
    try_files $uri $uri/ /mobile/index.html;
}
```

### Características web
- **PWA Ready:** Incluye Service Worker para funcionamiento offline
- **Responsive:** Funciona en todos los tamaños de pantalla
- **Single Page Application:** Carga rápida después de inicialización

### Fecha de compilación
14 de abril de 2026

---

## 📋 Notas de compilación

### Dependencias
- Flutter SDK actualizado
- Todas las dependencias de `pubspec.yaml` descargadas y compiladas
- 5 dependencias actualizadas automáticamente durante el proceso

### Advertencias (no críticas)
- **Java compiler:** Versión 8 obsoleta (no afecta funcionalidad)
- **WebAssembly:** Algunas librerías no son completamente compatibles con WASM (no utilizado por defecto)
- **Icon tree-shaking:** Iconos no utilizados fueron eliminados para reducir tamaño

### Versiones de Android
- **Gradle:** Compilado exitosamente
- **Targetted APIs:** Configurados según `build.gradle.kts`

---

## 🔄 Próximos pasos

1. **Testing:** Probar cada versión en sus respectivas plataformas
2. **Distribución:**
   - APK: Enviar a testers o a Play Store
   - Linux: Empaquetar si es necesario
   - Web: Desplegar en servidor con base path `/mobile/`
3. **Monitoreo:** Verificar logs y errores en producción

---

## 📞 Información de contacto

Para preguntas sobre estas compilaciones, consulte el README.md principal o la documentación del proyecto.

**Última actualización:** 14 de abril de 2026
