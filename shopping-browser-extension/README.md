# Brillitos Shopping — extensión de prueba para Chrome

Esta extensión permite probar la lectura directa del contenido visible de una pestaña de tienda ya abierta. No pide ni envía contraseñas y no realiza compras.

## Instalar para probar

1. Descarga el código de esta carpeta o el ZIP de la rama del repositorio.
2. Extrae el ZIP en una carpeta.
3. En Chrome abre `chrome://extensions`.
4. Activa **Modo de desarrollador**.
5. Pulsa **Cargar descomprimida** y selecciona la carpeta `shopping-browser-extension`.
6. Abre tu carrito en SHEIN, Amazon, Temu o AliExpress e inicia sesión tú misma en el sitio oficial.
7. Pulsa el icono de la extensión y luego **Leer esta página**.

Si la extensión no aparece tras instalarla, recarga la pestaña de la tienda. El acceso de sitios puede requerir que Chrome autorice la extensión para ese dominio.

## Límites conocidos

- Cada tienda cambia su HTML con frecuencia; los selectores son heurísticos y puede que alguna tienda no devuelva todos los productos.
- El extractor lee la página visible que ya se cargó; no accede a APIs privadas ni evita controles anti-bot.
- Los precios, variantes y cantidades deben verificarse.
- La exportación JSON es local. Todavía no escribe en Supabase ni en Brillitos Admin.
- Prototipo experimental, no auditoría de seguridad ni versión de producción.
