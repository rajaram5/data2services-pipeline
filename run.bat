
:: Generate RML mapping.ttl file
docker run -it --rm --link drill:drill -v %1:/data autodrill -h drill -r -o /data/mapping.ttl %1

:: Generate config.properties required for r2rml
echo "connectionURL = jdbc:drill:drillbit=drill:31010
mappingFile = /data/mapping.ttl
outputFile = /data/rdf_output.nq
format = NQUADS" > %1/config.properties

:: Run r2rml to generate RDF files
docker run -it --rm --link drill:drill -v %1:/data r2rml /data/config.properties

:: Run RdfUpload to upload to GraphDB
docker run -it --rm --link graphdb:graphdb -v %1:/data rdf-upload \
  -m "HTTP" \
  -if "/data/rdf_output.nq" \
  -url "http://graphdb:7200" \
  -rep "test" \
  -un import_user -pw test
