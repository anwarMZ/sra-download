#!/usr/bin/env nextflow

params.input = ""

params.output = ""

outputDir = file(params.output)

sraIds = Channel.create()

Channel
    .fromPath(params.input)
    .splitCsv(header: true, sep:'\t' )
    .map {it.ena_run_accession}
    .into(sraIds)



process filter {

    errorStrategy 'retry'

    maxRetries 5

    maxErrors 50000

    tag { id + '_filter'}

    input:
    val id from sraIds

    output:
    stdout out into testedSraIds

    shell:
    '''
    #!/bin/bash
    READ_RUN=$(wget -qO- 'http://www.ebi.ac.uk/ena/data/warehouse/filereport?accession=!{id}&result=read_run' | tail -n +2)
    if [[ -z "$READ_RUN" ]]; then
         printf "not_found"
    else
         printf "!{id}"
    fi
    '''
}

filteredSraIds = Channel.create()
testedSraIds
   .filter({!it.equals("not_found")})
   .into(filteredSraIds)

process fetchSRA {

    errorStrategy 'retry'

    maxRetries 5

    maxErrors 50000

    tag { id + '_fastq_dump'}

    input:
    val id from filteredSraIds

    output:
    val id  into fastqIds

    """
     fastq-dump --readids --gzip --split-3  ${id} -O ${outputDir}
    """
}
