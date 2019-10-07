Channel.fromFilePairs("../sequences/*_{1,2}.fastq.gz")
        .set{ sequence_pairs_ch }

process AdapterRemovalV2 {
    conda 'bioconda::adapterremoval'
    cpus 6
    publishDir './processed/', mode: 'copy'
    input: 
        set strain, file(reads) from sequence_pairs_ch

    output:
        set val(strain), file("${strain}.*") into processed_reads_ch
        file("${strain}.settings") into qc_report_ch

    """
    AdapterRemoval \
        --file1 ${reads[0]} \
        --file2 ${reads[1]} \
        --threads 6 \
        --basename ${strain} \
        --gzip \
        --collapse

    """
}

process MultiQC {
    conda 'bioconda::multiqc'
    publishDir './Processing_MultiQC_output'

    input:
        file(settings_out) from qc_report_ch.collect()

    output:
        file("multiqc_report.html")
        file("multiqc_data")

    """
    multiqc .
    """
}

process runMegahitAssembler {
    conda 'bioconda::megahit'
    cpus 6
    maxForks 2
    publishDir "./Assemblies", mode: 'copy'
    input: 
        set sequence_id, file(files) from processed_reads_ch
    
    output:
        file("${sequence_id}.contigs.fa")

    // collapsed, pair1, pair2, singletons

    // TODO: Get the error, then come back and add the renaming...

    """

    zcat *collapsed*gz > merged.fq
    mv ${sequence_id}.pair1.truncated.gz pair1.fq.gz
    mv ${sequence_id}.pair2.truncated.gz pair2.fq.gz
    mv ${sequence_id}.singleton.truncated.gz singles.fq.gz
    
    megahit -1 pair1.fq.gz -2 pair2.fq.gz \
        -r merged.fq,singles.fq.gz \
        -t 6 \
        -o output \
        --out-prefix ${sequence_id}

    mv output/${sequence_id}.contigs.fa ${sequence_id}.contigs.fa
    """
}

/*
process runSpadesAssembler {
    conda 'bioconda::spades'
    cpus 4
    maxForks 2
    input: 
        set sequence_id, file(files) from processed_reads_ch

    // collapsed, pair1, pair2, singletons

    // TODO: Get the error, then come back and add the renaming...

    """
    spades.py \
        -o output \
        -1 ${files[1]} -2 ${files[2]} \
        --merged ${files[0]} \
        -s ${files[3]} \
        -t 4 \
        -m 64 \
        --careful

    """
} */