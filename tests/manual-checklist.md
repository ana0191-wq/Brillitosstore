# Validación manual de tienda y Admin

Usar productos y pedidos de prueba identificables. Anotar el stock inicial de cada variante y cancelar las ventas al terminar. No enviar pagos reales.

1. Abrir la tienda y el Admin en una ventana nueva. Confirmar la versión `v20260921-atomic-inventory`.
2. Elegir un producto de $100 sin remate, con stock y cubierto por la promoción. Hasta el 30/09/2026 inclusive, en horario de Caracas, debe quedar en $80. Con Binance debe dar $72: el 10% se aplica después del 20%.
3. Comprobar que un producto de menos de $4 no recibe esta promoción. En un producto en remate, comprobar que se usa el precio de remate sin sumar el 20%; Binance descuenta el 10% sobre ese precio.
4. Cambiar entre Binance y otro método. Comprobar que el descuento Binance desaparece al cambiar y que la moneda y el importe final corresponden al método seleccionado.
5. Completar una compra de prueba. Comparar carrito, mensaje de WhatsApp y detalle de venta en Admin: productos, variantes, cantidades, promociones, descuento Binance e importe de pago deben coincidir.
6. Confirmar que el pedido web pendiente aparece una sola vez y todavía no reduce stock. Marcarlo Pagado: reduce exactamente la cantidad comprada. Marcarlo Entregado: no vuelve a reducir stock.
7. Cancelar la venta: debe restaurar exactamente el stock. Repetir la cancelación: no debe añadir unidades adicionales.
8. Editar una venta pagada cambiando cantidades o variantes. Verificar que devuelve las unidades anteriores y descuenta las nuevas. Intentar una cantidad superior al stock: debe conservar íntegramente la venta y el inventario anteriores.
9. Crear una consulta/apartado web con variante. Convertirla en venta desde Admin y verificar variante, precio y stock. Repetir la conversión: no debe crear otra venta ni descontar dos veces.
10. En dos pestañas, intentar confirmar ventas que exceden juntas el stock disponible. Solo debe completarse la cantidad que permita el inventario; la otra operación debe informar el error sin guardar cambios parciales.
11. Interrumpir la conexión al confirmar una compra. El carrito debe permanecer disponible. Restablecer la conexión y reintentar: verificar que no aparece un segundo pedido por la misma solicitud.
12. Cambiar el precio de un producto después de añadirlo al carrito. Al comprar, la tienda debe actualizar el importe y pedir una nueva confirmación.
13. En Productos del Admin, probar búsqueda por nombre, ID y variante, filtros, ordenación y paginación. Expandir variantes y comprobar sus existencias y precios. Revisar las tarjetas en móvil y escritorio.
14. Verificar vencimiento en un entorno de pruebas: a las 23:59:59 del 30/09/2026 en Caracas aplica el 20%; a las 00:00 del 01/10 ya no. Binance conserva su 10%. Cambiar únicamente el reloj del navegador no altera la cotización del servidor.
15. Subir una foto desde Productos o producto rápido: debe solicitar la clave de almacenamiento de Bunny en un campo oculto. Cancelar no debe subir nada. Una clave incorrecta debe permitir introducirla de nuevo. Recargar la página debe exigir la clave otra vez; las fotos existentes siguen visibles sin introducirla.

Las pruebas automatizadas SQL usan transacciones con rollback. La autenticación y los permisos quedan pendientes de una revisión separada.

La clave privada de Bunny se retiró del código actual. La solución temporal de carga conserva la clave introducida solo en memoria de la pestaña. No elimina su exposición histórica: debe rotarse en Bunny. La carga autenticada mediante servidor sigue pendiente.

## Pedidos por cliente

1. En la tienda, intentar enviar un pedido sin nombre o WhatsApp: debe solicitar los datos antes de guardarlo.
2. Completar los datos y enviar una compra de prueba. Confirmar el número `WEB-V…` (o `WEB-C…` para consulta) y el nombre en WhatsApp y en Admin → Pedidos por cliente.
3. Hacer otro pedido con el mismo nombre y teléfono: ambos deben aparecer bajo el mismo cliente. Clientes con nombres iguales y teléfonos diferentes deben permanecer separados.
4. En Pedidos por cliente, seleccionar un cliente y pulsar + Pedido manual. Debe abrir una cotización sin reserva de stock; guardar productos y verificar que aparece en su grupo.
5. Buscar por cliente, número y producto; filtrar pedidos web sin revisar; marcar uno revisado. Recargar y verificar que conserva esa marca en ese navegador.
6. Asignar un pedido antiguo al cliente correcto. Confirmar que cambia de grupo sin cambiar importes, productos ni stock. Si falla la conexión, el formulario debe informar el fallo.
7. Activar avisos y mantener el Admin abierto. Registrar un nuevo pedido web desde otro navegador y esperar hasta un minuto: debe actualizar el contador y mostrar el aviso. Los navegadores pueden limitar los avisos en segundo plano.

No hay envío por correo configurado. Los avisos actuales necesitan el Admin abierto; no sustituyen un servicio de correo o notificaciones push en segundo plano.
