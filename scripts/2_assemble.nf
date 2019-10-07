Channel.fromFilePairs("./processed/*.{collapsed.truncated,pair1.truncated,pair2.truncated,singleton.truncated}.gz", flat: true, size: -1)
    .set { processed_reads_ch }

    processed_reads_ch.println()

process runSpadesAssembler {
    conda 'bioconda::spades'
    cpus 4
    maxForks 2
    input: 
        set sequence_id, collapsed, pair1, pair2, singletons from processed_reads_ch

    // TODO: Get the error, then come back and add the renaming...

    """
    spades.py \
        -o output \
        -1 ${pair1} -2 ${pair2} \
        --merged ${collapsed} \
        -s ${singletons} \
        -t 4 \
        -m 64 \
        --careful

    """
}