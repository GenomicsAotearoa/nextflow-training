

sequence_files_ch = Channel.fromFilePairs("../sequences/*_{1,2}.fastq.gz").println()