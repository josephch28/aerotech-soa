"""Generación y control de asientos. Toda operación que cambie asientos debe
llamar primero a `bloquear_vuelo` dentro de una sola transacción."""
from errores import ErrorApi


def letras(config: str) -> list[str]:            # "ABC-DEF" -> ["A","B","C","D","E","F"]
    return [c for c in config if c != "-"]


def generar_asientos(cur, vuelo_id: int, avion: dict) -> int:
    filas_salida = set(avion["filas_salida"] or [])
    filas = []
    for fila in range(1, avion["filas"] + 1):
        ejecutiva = fila <= avion["filas_ejecutiva"]
        conf = (avion["configuracion_ejecutiva"] or avion["configuracion"]) if ejecutiva else avion["configuracion"]
        for letra in letras(conf):
            filas.append((vuelo_id, f"{fila}{letra}", fila, letra,
                          "ejecutiva" if ejecutiva else "economica", fila in filas_salida))
    cur.executemany("""INSERT INTO asientos (vuelo_id, codigo, fila, columna, clase, salida_emergencia)
                       VALUES (%s,%s,%s,%s,%s,%s)""", filas)
    recontar(cur, vuelo_id)
    return len(filas)


def recontar(cur, vuelo_id):
    cur.execute("""UPDATE vuelos SET asientos_disponibles =
                   (SELECT count(*) FROM asientos WHERE vuelo_id=%s AND estado='disponible')
                   WHERE id=%s""", (vuelo_id, vuelo_id))


def bloquear_vuelo(cur, vuelo_id) -> dict:
    """SIEMPRE llamar primero en cualquier operación que cambie asientos: serializa por vuelo."""
    cur.execute("SELECT * FROM vuelos WHERE id=%s FOR UPDATE", (vuelo_id,))
    v = cur.fetchone()
    if not v:
        raise ErrorApi("Vuelo no encontrado", 404)
    return v


def obtener_asientos(cur, vuelo_id, codigos) -> dict[str, dict]:
    cur.execute("SELECT * FROM asientos WHERE vuelo_id=%s AND codigo = ANY(%s)", (vuelo_id, codigos))
    encontrados = {a["codigo"]: a for a in cur.fetchall()}
    inexistentes = sorted(set(codigos) - encontrados.keys())
    if inexistentes:
        raise ErrorApi(f"Asientos inexistentes: {', '.join(inexistentes)}", 400)
    return encontrados


def ocupar(cur, vuelo_id, reserva_id, codigos):
    cur.execute("""UPDATE asientos SET estado='ocupado', reserva_id=%s
                   WHERE vuelo_id=%s AND codigo = ANY(%s) AND estado='disponible'
                   RETURNING codigo""", (reserva_id, vuelo_id, codigos))
    ok = {r["codigo"] for r in cur.fetchall()}
    fallidos = sorted(set(codigos) - ok)
    if fallidos:   # la transacción completa hace rollback
        raise ErrorApi(f"Asientos no disponibles: {', '.join(fallidos)}", 409,
                       extra={"asientos_no_disponibles": fallidos})


def liberar_de_reserva(cur, reserva_id):
    cur.execute("UPDATE asientos SET estado='disponible', reserva_id=NULL WHERE reserva_id=%s", (reserva_id,))
