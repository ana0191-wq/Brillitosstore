# Brillitos Shopping (prototipo Windows)

Aplicación de escritorio independiente basada en Electron. No modifica el Admin existente.

## Requisitos
- Windows 10/11
- Node.js LTS instalado desde https://nodejs.org/

## Ejecutar
1. Descarga/clona el repositorio.
2. Abre PowerShell dentro de `shopping-browser`.
3. Ejecuta `npm install`.
4. Ejecuta `npm start`.

## Funciones actuales
- Navegador integrado con botones para SHEIN, Amazon, Temu y AliExpress.
- Perfil de sesión persistente local para las tiendas.
- Lector experimental de productos visibles en la página actual.
- Revisión básica de nombre, enlace, variante, cantidad y precio cuando el sitio lo expone en el DOM.
- Exportación de datos a JSON.

## Limitaciones importantes
La extracción es heurística y no está garantizada en todas las páginas ni en todas las tiendas. No automatiza compras ni supera CAPTCHAs o restricciones de acceso. No captura contraseñas fuera de la página de la tienda. Los datos extraídos requieren revisión manual.

La conexión directa a Supabase/Brillitos Admin todavía no está habilitada. Antes de activarla hay que implementar autenticación y una vía segura de escritura; no incluir una clave service-role en la aplicación de escritorio.
