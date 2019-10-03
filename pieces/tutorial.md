# Nextflow Tutorial
## Installing Nextflow
```console
guhjo98p@ga-vl01 ~> wget -qO- https://get.nextflow.io | bash
```
or
```console
guhjo98p@ga-vl01 ~> conda install bioconda::nextflow
```

Test it with
```console
josephguhlin@josephguhlin ~> nextflow run hello

N E X T F L O W  ~  version 19.09.0-edge
Launching `nextflow-io/hello` [kickass_shaw] - revision: a9012339ce [master]
WARN: The use of `echo` method is deprecated
executor >  local (4)
[0e/08264c] process > sayHello (2) [100%] 4 of 4 ✔
Hola world!

Bonjour world!

Hello world!

Ciao world!

josephguhlin@josephguhlin ~>
```

## Channels
Think of pipes
Data in --> Channel --> Data out

```Nextflow
Channel.fromFilePairs("../sequences/*_{1,2}.fastq.gz")
        .set { sequence_files_ch }
```

Creates a channel of all read pairs, emitting each as a sequence name followed by a tuple of the files.

## Processes
Takes one (or more) inputs from one (or more) channels and outputs to one (or more) channels
```Nextflow
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
```

## Stringing from one process to another
```Nextflow
process MultiQC {
    conda 'bioconda::multiqc'
    publishDir './MultiQC_output'

    input:
        file(fastqc_out) from fastqc_output_ch.collect()

    output:
        file("multiqc_report.html")
        file("multiqc_data")

    """
    multiqc .
    """
}
```

## Final script 0_qc.nf
```Nextflow
Channel.fromFilePairs("/scale_wlg_nobackup/filesets/nobackup/nesi02646/nextflow-tutorial/nf-tutorial/sequences/*_{1,2}.fastq.gz")
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

process MultiQC {
    conda 'bioconda::multiqc'
    publishDir './MultiQC_output'

    input:
        file(fastqc_out) from fastqc_output_ch.collect()

    output:
        file("multiqc_report.html")
        file("multiqc_data")

    """
    multiqc .
    """
}
```

