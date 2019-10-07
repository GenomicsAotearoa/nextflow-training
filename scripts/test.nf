Channel.fromFilePairs("../sequences/*_{1,2}.fastq.gz")
        .set { sequence_files_ch }

process fastQC {
    conda 'bioconda::fastqc'

    input:
        set strain, file(reads) from sequence_files_ch

    output:
        file("*_fastqc.zip") into fastqc_output_ch

    """
        mkdir output
        fastqc -o . \
        -f fastq \
        -t 6 \
        ${reads}

    """
}

