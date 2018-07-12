# To do for automation

* One directory per dataset
* Example:
  * pharmkgb_gene
    * mappings.ttl (mapping file generated by AutoDrill)
    * config.properties (that we have to generate with proper mappingFile from AutoDrill and outputFile path)
    * rdf_output.ttl (the file generated by r2rml, defined in config.properties)
* We will need a web service to handle everything
  * Someone post a dataset or send a get with a dataset URL
  * We download it and run each step
  * Use **tomcat**? And Spring or jersey?
* Later we will need individual log files for each step for each dataset



# Quick run

```shell
# Run Drill and access it at http://localhost:8047
docker run -it --rm -p 8047:8047 -p 31010:31010 --name drill -v /data:/data:ro drill /drill-scripts/bootstrap.sh
# Detached
docker run -dit --rm -p 8047:8047 -p 31010:31010 --name drill -v /data:/data:ro drill /drill-scripts/bootstrap.sh

# Run GraphDB and access it at http://localhost:7200
cd graphdb/
./run.sh

# Run AutoDrill on Pharmgkb and store mappings in a file
docker run -it --rm --link drill:drill autodrill -h 172.17.0.2 -r /data/drill/pharmgkb/ > /tmp/pharmgkb_gene_mapping.ttl
# Put the file in data
sudo mv /tmp/pharmgkb_gene_mapping.ttl /data/mappings/

# Then run r2rml to generate mappings
docker run -it --rm --link drill:drill -v /data:/data r2rml /data/mappings/config.properties

# Then use RdfUpload to upload the RDF file to GraphDB
# TODO: CHANGE THE FILEPATH 
docker run -it --rm -v /data/rdfu:/data rdf-upload -if "/data/affymetrix_test.ttl" -ep "http://172.17.0.3:7200/repositories/kraken_test" -uep "http://172.17.0.3:7200/repositories/kraken_test/statements" -un admin -pw admin
```



# Running the pipeline

```shell
# Create a directory with your data files in /drill.
# e.g.: /data/pharmagkb_drugs/drill/drugs.tsv

./run.sh -d /data/pharmagkb_drugs
[-d] Working directory: 
[-dr] Drill: 172.17.0.2
[-db] GraphDB host: 172.17.0.3
[-gr] GraphDB repository: kraken_test
```





# Building the pipeline

## OLD Run Apache Drill in background

Not detached to get console feedback

From https://github.com/vemonet/apache-drill-docker (forked from amalic, forked from mkieboom)

v1.13.0: https://github.com/vemonet/apache-drill-docker/tree/master/1.13.0

Docs: https://www.tutorialspoint.com/apache_drill/index.htm

```shell
cd apache-drill-docker/1.6.0/
#cd apache-drill-docker/1.13.0/
docker build -t drill .
# 8047 is HTTP port and 31010 is Drill port
docker run -it --rm -p 8047:8047 -p 31010:31010 --name drill -v /data:/data:ro drill /drill-scripts/bootstrap.sh
# On Windows
docker run -it --rm -p 8047:8047 -p 31010:31010 --name drill -v c:/data:/data:ro drill /drill-scripts/bootstrap.sh

# HTTP access: http://localhost:8047
# Navigate in dir
show files in dfs.root.`/`;
# Select on CSV Example
SELECT * FROM cp.`employee.json` LIMIT 5;

# Attach to a drill docker container with bash
docker exec -it drill bash
```

Leave the Drill command line using Ctrl+P+Q



## Run Apache Drill in background

```shell
git clone git@github.com:vemonet/apache-drill.git

# Forked from amalic
git remote add 
upstream  git@github.com:amalic/apache-drill.git
git fetch upstream
git merge upstream/master
```

Docs: https://www.tutorialspoint.com/apache_drill/index.htm

### Download apache-drill

```
wget ftp://apache.proserve.nl/apache/drill/drill-1.13.0/apache-drill-1.13.0.tar.gz
```

### Build

```
docker build -t apache-drill .
```

### Run

```shell
docker run -dit --rm -p 8047:8047 -p 31010:31010 --name drill -v /data:/data:ro apache-drill

# On Windows
docker run -dit --rm -p 8047:8047 -p 31010:31010 --name drill -v c:/data:/data:ro apache-drill

# HTTP access: http://localhost:8047
# Navigate in dir
show files in dfs.root.`/`;
# Select on CSV Example
SELECT * FROM cp.`employee.json` LIMIT 5;

# Attach to a drill docker container with bash
docker exec -it drill bash
```

`-d` for detached. Remove it to get live console feedback

Leave the Drill command line using Ctrl+P+Q



## AutoDrill (autodrill2rml)

Generate mapping file by extracting columns headers (mappings are then used to name the predicates)

- Run docker container linked to Drill container

```shell
docker build -t autodrill .

# Run it on IDS server
docker run -it --rm autodrill -h node000002.cluster.ids.unimaas.nl -r /data/tmp/drill/pharmgkb/

# Run it on local server
docker run -it --rm --link drill:drill autodrill -h localhost -r /data/drill/pharmgkb/
# Avec drugs
docker run -it --rm --link drill:drill autodrill -h 172.17.0.2 -r /data/pharmgkb_drugs/ > /data/pharmgkb_drugs/mappings.ttl

docker run -it --rm --link drill:drill autodrill -h 172.17.0.2 -p 31010:31010 -r /data/pharmgkb_drugs/
docker run -it --rm --link drill:drill autodrill -h localhost -p 8047:8047 -r /data/pharmgkb_drugs/

# With container IP address:
docker run -it --rm --link drill:drill autodrill -h 172.17.0.2 -r /data/drill/pharmgkb/
# Note: works even when removing --link

# PROBLEMS TO SOLVE
oadd.io.netty.channel.AbstractChannel$AnnotatedConnectException: Connection refused
# Get drill container IP address (to use instead of localhost)
docker inspect <container_id> | grep "IPAddress"
```

* Run AutoDrill on IntelliJ

  In Run configuration:

  * Main class

    ```
    nl.unimaas.ids.autodrill.AutoDrill
    ```

  * Program arguments

    ```shell
    -h node000002.cluster.ids.unimaas.nl -r /data/tmp/drill/pharmgkb/
    ```




## r2rml

Generate RDF file from relational database using the RML mapping file previously generated (by AutoDrill)

See `run.sh`

```shell
cd r2rml/
docker build -t r2rml .

# Run r2rml on a file
docker run -it --rm --link drill:drill -v /data:/data r2rml /data/mappings/config.properties
# On Windows
docker run -it --rm --link drill:drill -v c:/data:/data r2rml /data/mappings/config.properties

# Convert pharmgkb
docker run -it --rm --link drill:drill -v /data:/data r2rml /data/pharmgkb_drugs/config.properties

# Everything is configured in the config.properties file
```

* `config.properties` file

```properties
connectionURL = jdbc:drill:drillbit=drill:31010
mappingFile = /data/mappings/pharmgkb_gene_mapping.ttl
outputFile = /data/drill_test_output.ttl.gz
format = TTL
```

* Error

  Not working on Pharmgkb data:  `SYSTEM ERROR: StackOverflowError`

  Tried to fix it by changing Xms, Xmx and Xss when running Jar

  ```shell
  ENTRYPOINT ["java", "-Xss4m","-Xms4096m", "-Xmx8192m","-jar","r2rml.jar"]
  ENTRYPOINT ["java", "-Xss16m","-Xms4096m", "-Xmx10496m","-jar","r2rml.jar"]
  ```

  But not working.

  Try with another file maybe? To check if the problem comes from pharmgkb

  Maybe it is a bad recursion



## RdfUpload

```shell
cd RdfUpload/
docker build -t rdf-upload .

# Example
docker run -it --rm -v /data/rdfu:/data rdf-upload -if "/data/rdffile.nt" -ep "http://myendpoint.org/sparql"

# Test with affymetrix ttl
docker run -it --rm -v /data/rdfu:/data rdf-upload -if "/data/affymetrix_test.ttl" -ep "http://localhost:7200/repositories/kraken_test" -uep "http://localhost:7200/repositories/kraken_test/statements" -un import_user -pw test

# TO FIX: access through localhost doesn't work, we need to use container IP
# TEST NETWORK CONNECT (see docker docs)
docker run -it --rm -v /data/rdfu:/data rdf-upload -if "/data/affymetrix_test.ttl" -ep "http://172.17.0.3:7200/repositories/kraken_test" -uep "http://172.17.0.3:7200/repositories/kraken_test/statements" -un admin -pw admin

docker run -it --rm -v c:/data/rdfu:/data rdf-upload -if "/data/affymetrix_test.ttl" -ep "http://172.17.0.3:7200/repositories/test_drill" -uep "http://172.17.0.3:7200/repositories/test_drill/statements" -un import_user -pw import_pwd
```



```shell
# Alex's params
-ep http://graphdb.dumontierlab.com/repositories/test_rdfupload
-uep http://graphdb.dumontierlab.com/repositories/test_rdfupload/statements
# uep: update endpoint. ep: endpoint
-un import_user
-pw test

-if /data/geospecies.rdf.gz
```

Change URL by my graphdb URL



## GraphDB

Run GraphDB triplestore in the background

```shell
cd graphdb/
docker build -t "graphdb:8.6.0" .
./run.sh

# Windows
docker run --detach --name graphdb --publish 7200:7200 --volume c:/data/graphdb:/opt/graphdb/home --volume c:/data/graphdb-import:/root/graphdb-import --rm graphdb:8.6.0
```

Then go to http://localhost:7200/repository and create kraken_test repository

* When creating repo, check "Use context index"
* Security ON
* Free access ON with read access to my repository
* Create import_user with password import_pwd: user with write access