# mediopixel-web

Web de Medio Pixel. HTML y CSS estáticos, sin paso de compilación.

- `docs/`: lo que se publica.
- `tools/serve.ps1`: servidor local en `http://localhost:8080`.
- `tools/export-images.ps1`: regenera las imágenes de `docs/assets/img` a partir de `Material/`, que no se sube al repositorio.

Las rutas entre páginas son relativas para que la web funcione igual en el dominio y en una subcarpeta.
