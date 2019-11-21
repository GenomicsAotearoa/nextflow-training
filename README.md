# Introduction
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
# Assembling these genomes
## Same starting channel
```Nextflow
Channel.fromFilePairs("/scale_wlg_nobackup/filesets/nobackup/nesi02646/nextflow-tutorial/nf-tutorial/sequences/*_{1,2}.fastq.gz")
        .set { sequence_files_ch }
```
## Process the reads
```Nextflow
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
```

## MultiQC the processed reads
```Nextflow
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
```

## Assemble with Megahit
```Nextflow
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
```

## Entire script
```Nextflow
Channel.fromFilePairs("/scale_wlg_nobackup/filesets/nobackup/nesi02646/nextflow-tutorial/nf-tutorial/sequences/*_{1,2}.fastq.gz")
        .set { sequence_files_ch }

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
```

```Console
guhjo98p@ga-vl01 /n/n/n/n/n/scripts> nextflow 1_processing_megahit.nf -with-report -with-trace                                                    (base)
N E X T F L O W  ~  version 19.07.0
Launching `1_processing_megahit.nf` [golden_spence] - revision: 989e7a108e
[-        ] process > AdapterRemovalV2    -
executor >  local (4)
executor >  local (4)
[3b/d59fb1] process > AdapterRemovalV2 (2) [  0%] 0 of 4
executor >  local (4)
[2a/b88dad] process > AdapterRemovalV2 (1) [ 25%] 1 of 4
executor >  local (9)
[77/6aa0b6] process > AdapterRemovalV2 (3)    [100%] 4 of 4 ✔
[8c/1c60e6] process > MultiQC                 [100%] 1 of 1 ✔
[02/70022d] process > runMegahitAssembler (4) [100%] 4 of 4 ✔
Completed at: 03-Oct-2019 22:39:43
Duration    : 14m 42s
CPU hours   : 3.2
Succeeded   : 9
```

# Output of Report

# Nextflow Documentation
https://www.nextflow.io/docs/latest/index.html

# Annotation the genomes
```Nextflow
Channel.fromPath("Assemblies/*.fa")
        .set { assemblies_ch }

process ProdigalAnnotate {
        module "prodigal/2.6.3-GCCcore-7.4.0"
        tag { "${assembly.baseName}" }
        input:
              	file(assembly) from assemblies_ch
        output:
               	file("*.faa") into proteins_ch


"""
prodigal -f gff -a ${assembly.baseName}.faa -i ${assembly}
"""

}
```

# Exercise: Combine the three files into a single script?
You can't re-use channels, so instead of setting the input channel, you will have to use "into"
```Nextflow
Channel.fromFilePairs("../sequences/*_{1,2}.fastq.gz")
        .into { fastqc_input_ch, trimming_input_ch }
```

# Exercise 2: Make it run on SLURM
You will need to add the cpus, time, memory settings to each process!
```Nextflow
process calculateRegions {
        tag { "Calculate regions" }
        // Runs fast so execute locally
        executor 'local'
        cpus 1
        cache false
        time '10m'
        memory '1000 MB'
        conda 'bioconda::freebayes'

...............

process FreeBayes {
        tag { "FreeBayes ${region_name}" }
        cpus 2
//      queue 'ga_hugemem'
        queue 'long'
        time '10d'
        memory '104 GB'
        conda 'bioconda::freebayes'
        storeDir './freebayes-regions/'
//      publishDir './freebayes-regions/'
................
```

And set up a nextflow.config file
```Nextflow
process {
	executor = "slurm"
    clusterOptions = "-A YOUR PROJECT ID"

}
```

On mahuika, launch a screen (to keep nextflow program running)

```Console
$ nextflow freebayes.nf -resume -qs 100
```

-qs says submit up to 100 jobs at a time (NeSI supports 1000, but it's best to not always overload it)
-resume is when a pipeline has had some failures and you've fixed things (or added additional resources)

# Combined SLURM Script
```Nextflow
Channel.fromFilePairs("../sequences/*_{1,2}.fastq.gz")
        .into { fastqc_input_ch; trimming_input_ch }

process fastQC {
    conda 'bioconda::fastqc'
    cpus 6
    time '30m'
    memory '16 GB'
    queue 'large'

    input:
        set strain, file(reads) from fastqc_input_ch

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

process MultiQC_fastq {
    conda 'bioconda::multiqc'
    publishDir './MultiQC_output'

    cpus 1
    time '10m'
    memory '8 GB'
    queue 'large'

    input:
        file(fastqc_out) from fastqc_output_ch.collect()

    output:
        file("multiqc_report.html")
        file("multiqc_data")

    """
    multiqc .
    """
}

process AdapterRemovalV2 {
    conda 'bioconda::adapterremoval'
    cpus 6
    time '30m'
    memory '32 GB'
    queue 'large'

    publishDir './processed/', mode: 'copy'
    input: 
        set strain, file(reads) from trimming_input_ch

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

process MultiQC_trimmed {
    conda 'bioconda::multiqc'
    publishDir './Processing_MultiQC_output'

    cpus 1
    time '20m'
    memory '8 GB'
    queue 'large'

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
    time '20m'
    memory '8 GB'
    queue 'large'
    publishDir "./Assemblies", mode: 'copy'
    input: 
        set sequence_id, file(files) from processed_reads_ch
    
    output:
        file("${sequence_id}.contigs.fa") into assemblies_ch

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

process ProdigalAnnotate {
        module "prodigal/2.6.3-GCCcore-7.4.0"

        cpus 1
        time '15m'
        memory '12 GB'
        queue 'large'

        tag { "${assembly.baseName}" }
        input:
              	file(assembly) from assemblies_ch
        output:
               	file("*.faa") into proteins_ch


"""
prodigal -f gff -a ${assembly.baseName}.faa -i ${assembly}
"""

}
```