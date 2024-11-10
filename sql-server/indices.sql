
CREATE FULLTEXT CATALOG <NombreCatalogo> AS DEFAULT;
-- <NombreCatalogo>: Nombre del catálogo Full-Text. Ejemplo: ftCatalog.
-- AS DEFAULT: Hace que este catálogo sea el predeterminado para nuevos índices Full-Text.

-- list catalogs
SELECT * FROM sys.fulltext_catalogs

CREATE FULLTEXT INDEX ON <NombreEsquema>.<NombreTabla> (<NombreColumna>)
    KEY INDEX <NombreIndiceClavePrimaria>
    ON <NombreCatalogo>;
-- <NombreEsquema>: Esquema de la tabla, comúnmente 'dbo'.
-- <NombreTabla>: Nombre de la tabla sobre la cual se crea el índice. Ejemplo: clientes.
-- <NombreColumna>: Columna de la tabla que será indexada. Ejemplo: indice_busqueda.
-- <NombreIndiceClavePrimaria>: Índice de la clave primaria de la tabla. Ejemplo: clientes_pk.
-- <NombreCatalogo>: Nombre del catálogo Full-Text creado anteriormente.
-- NOTA: El índice de clave primaria es necesario para relacionar cada entrada en el índice Full-Text con una fila específica en la tabla.

CREATE FULLTEXT INDEX ON <NombreEsquema>.<NombreTabla> 
(
    <NombreColumna1>,
    <NombreColumna2>,
    ...
)
KEY INDEX <NombreIndiceClavePrimaria>
ON <NombreCatalogo>;
-- example use index name not column

CREATE FULLTEXT INDEX ON dbo.clientes 
(indice_busqueda) KEY INDEX clientes_pk ON ftClients;

ALTER FULLTEXT INDEX ON <NombreEsquema>.<NombreTabla> SET CHANGE_TRACKING AUTO;
-- <NombreEsquema>: Esquema de la tabla, comúnmente 'dbo'.
-- <NombreTabla>: Nombre de la tabla con el índice Full-Text. Ejemplo: clientes.
-- CHANGE_TRACKING AUTO: Configura el índice para actualizar automáticamente cuando los datos de la tabla cambian.



SELECT * FROM <NombreEsquema>.<NombreTabla>
WHERE CONTAINS(<NombreColumna>, '<TerminoBusqueda>');
-- <NombreEsquema>: Esquema de la tabla, comúnmente 'dbo'.
-- <NombreTabla>: Nombre de la tabla con el índice Full-Text. Ejemplo: clientes.
-- <NombreColumna>: Columna indexada por Full-Text. Ejemplo: indice_busqueda.
-- <TerminoBusqueda>: Término o frase que estás buscando. Ejemplo: 'palabra clave'.

ejemplos:

-- agregar / eliminar columna de indice textfull
ALTER FULLTEXT INDEX ON dbo.clientes ADD (indice_busqueda);
ALTER FULLTEXT INDEX ON dbo.clientes DROP (indice_busqueda);

-- reconstruccion de indice de texto
ALTER FULLTEXT INDEX  ON dbo.clientes START FULL POPULATION;