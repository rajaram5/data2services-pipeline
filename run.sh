#!/bin/bash

# Get commandline options
while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo "$package - attempt to capture frames"
                        echo " "
                        echo "$package [options] application [arguments]"
                        echo " "
                        echo "options:"
                        echo "-h, --help                show brief help"
                        echo "-f, --file-directory=/data/file_repository       specify a working directory with tsv, csv and/or psv data files to convert"
                        echo "-j, --jdbc-url=jdbc:drill:drillbit=drill:31010       The JDBC URL used to access the data for AutoR2RML (Drill, SQLite, Postgres)"
                        echo "-jc, --jdbc-container=drill      JDBC DB docker container name to link to AutoR2RML container. Default: drill"
                        echo "-ju, --jdbc-username=foo      JDBC DB username for AutoR2RML"
                        echo "-jp, --jdbc-password=bar      JDBC DB password for AutoR2RML"
                        echo "-gr, --graphdb-repository=test      specify a GraphDB repository. Default: test"
                        echo "-fo, --format=nquads      Specify a format for RDF out when running r2rml. Default: nquads"
                        echo "-gu, --graphdb-username=import_user      GraphDB username to upload RDF. Default: import_user"
                        echo "-gp, --graphdb-password=test      GraphDB password to upload RDF. Default: import_user"
                        exit 0;;
                -f)
                        shift
                        if test $# -gt 0; then
                                export DIRECTORY=$1
                        else
                                echo "No file directory specified. Should point to a directory thats contains tsv, csv and/or psv data files to convert."
                                exit 1
                        fi
                        shift;;
                --file-directory*)
                        export DIRECTORY=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift;;
                -j)
                        shift
                        if test $# -gt 0; then
                                export JDBC_URL=$1
                        else
                                echo "The JDBC URL used to access the data for AutoR2RML (Drill, SQLite, Postgres)"
                                exit 1
                        fi
                        shift;;
                --jdbc-url*)
                        export JDBC_URL=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift;;
                -ju)
                        shift
                        if test $# -gt 0; then
                                export JDBC_USERNAME=$1
                        fi
                        shift;;
                --jdbc-username*)
                        export JDBC_USERNAME=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift;;
                -jp)
                        shift
                        if test $# -gt 0; then
                                export JDBC_PASSWORD=$1
                        fi
                        shift;;
                --jdbc-password*)
                        export JDBC_PASSWORD=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift;;
                -jc)
                        shift
                        if test $# -gt 0; then
                                export JDBC_CONTAINER=$1
                        fi
                        shift;;
                --jdbc-container*)
                        export JDBC_CONTAINER=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift;;
                -rep)
                        shift
                        if test $# -gt 0; then
                                export GRAPHDB_REPOSITORY=$1
                        fi
                        shift;;
                --graphdb-repository*)
                        export GRAPHDB_REPOSITORY=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift;;
                -gu)
                        shift
                        if test $# -gt 0; then
                                export GRAPHDB_USERNAME=$1
                        fi
                        shift;;
                --graphdb-username*)
                        export GRAPHDB_USERNAME=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift;;
                -gp)
                        shift
                        if test $# -gt 0; then
                                export GRAPHDB_PASSWORD=$1
                        fi
                        shift;;
                --graphdb-password*)
                        export GRAPHDB_PASSWORD=`echo $1 | sed -e 's/^[^=]*=//g'`
                        shift;;
                *)
                        break;;
        esac
done

# Set default values
GRAPHDB_REPOSITORY=${GRAPHDB_REPOSITORY:-test}
GRAPHDB_USERNAME=${GRAPHDB_USERNAME:-import_user}
GRAPHDB_PASSWORD=${GRAPHDB_PASSWORD:-test}


echo "[-f] Working file directory: $DIRECTORY"
echo "[-j] JDBC URL for AutoR2RML: $JDBC_URL"
echo "[-jc] JDBC DB container for AutoR2RML: $JDBC_CONTAINER"
echo "[-ju] JDBC DB username for AutoR2RML: $JDBC_USERNAME"
echo "[-jp] JDBC DB password for AutoR2RML: $JDBC_PASSWORD"
echo "[-rep] GraphDB repository: $GRAPHDB_REPOSITORY"
echo "[-gu] GraphDB username: $GRAPHDB_USERNAME"
echo "[-gp] GraphDB password: $GRAPHDB_PASSWORD"



#if [ ${file: -4} == ".xml" || ${file: -7} == ".xml.gz" ]
if [[ $file == *.xml || $file == *.xml.gz ]]
then

  echo "---------------------------------"
  echo "  Running xml2rdf..."
  echo "---------------------------------"

  docker run --rm -it -v /data:/data xml2rdf  -i "$DIRECTORY" -o "$DIRECTORY.nq.gz" -g "http://kraken/graph/xml2rdf"
  # XML file needs to be in /data. TODO: put the first part of the path as the shared volume

  # Works on Pubmed, 3G nt file: 
  #docker run --rm -it -v /data:/data/ xml2rdf "/data/kraken-download/datasets/pubmed/baseline/pubmed18n0009.xml" "/data/kraken-download/datasets/pubmed/pubmed.nt.gz"
  # Error, needs dtd apparently
  #docker run --rm -it -v /data:/data/ xml2rdf "/data/kraken-download/datasets/interpro/interpro.xml" "/data/kraken-download/datasets/interpro/interpro.nt.gz"


else

  echo "---------------------------------"
  echo "  Converting TSV to RDF..."
  echo "---------------------------------"
  echo "Running AutoR2RML..."

  # Run AutoR2RML to generate R2RML mapping files

  # TODO: WARNING the $DIRECTORY passed at the end is the path INSIDE the Apache Drill docker container (it must always starts with /data).
  # So this script only works with dir inside /data)
  # Not working for sqlite: docker run -it --rm --link drill:drill -v $DIRECTORY:/data autor2rml -h drill -r -o /data/mapping.ttl $DIRECTORY
  docker run -it --rm --link $JDBC_CONTAINER:$JDBC_CONTAINER -v $DIRECTORY:/data autor2rml -j "$JDBC_URL" -r -o /data/mapping.ttl -d $DIRECTORY -u "$JDBC_USERNAME" -p "$JDBC_PASSWORD"
  # Flag to define the graph URI: -g "http://graph/test/autodrill"

  echo "R2RML mappings (mapping.ttl) has been generated."

  echo "Running r2rml..."

  # Generate config.properties required for r2rml
  echo "connectionURL = $JDBC_URL
  mappingFile = /data/mapping.ttl
  outputFile = /data/rdf_output.nq
  user = $JDBC_USERNAME
  password = $JDBC_PASSWORD
  format = NQUADS" > $DIRECTORY/config.properties

  # Run r2rml to generate RDF files. Using config.properties at the root dir of the container
  docker run -it --rm --link $JDBC_CONTAINER:$JDBC_CONTAINER -v $DIRECTORY:/data r2rml /data/config.properties

  echo "r2rml completed."

  # To run it with local config.properties:
  #docker run -it --rm --link drill:drill -v /data/kraken-download/datasets/pharmgkb:/data r2rml /data/config.properties

fi

echo "---------------------------------"
echo "  Running RdfUpload..."
echo "---------------------------------"

# Run RdfUpload to upload to GraphDB
docker run -it --rm --link graphdb:graphdb -v $DIRECTORY:/data rdf-upload \
  -m "HTTP" \
  -if "/data" \
  -url "http://graphdb:7200" \
  -rep "$GRAPHDB_REPOSITORY" \
  -un $GRAPHDB_USERNAME -pw $GRAPHDB_PASSWORD
