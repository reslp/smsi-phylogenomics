.. role:: bash(code)
   :language: bash


.. _BUSCO: https://busco-archive.ezlab.org/
.. _YAML: https://en.wikipedia.org/wiki/YAML
.. _Augustus: http://bioinf.uni-greifswald.de/augustus/
.. _mafft: https://mafft.cbrc.jp/alignment/server/
.. _trimal: http://trimal.cgenomics.org/
.. _raxml-ng: https://github.com/amkozlov/raxml-ng
.. _iqtree: http://www.iqtree.org/
.. _astral: https://github.com/smirarab/ASTRAL
.. _NCBI Genome Browser: https://www.ncbi.nlm.nih.gov/genome/browse#!/overview/
.. _biomartr: https://github.com/ropensci/biomartr
 
======================
phylociraptor runmodes
======================

A phylociraptor analysis is split into different parts, which also correspond to typical steps in a phylogenomic analysis. Each part is represented by it's own runmode and can be run independently. However runmodes can depend on each other (eg. for calculating a tree you will first have to create alignments) and are therefore typically executed in this order:

.. code-block:: bash

	$ phylociraptor orthology
	$ phylociraptor filter-orthology
	$ phylociraptor align
	$ phylociraptor filter-align
	$ phylociraptor njtree

We will now talk about the different runmodes individually.


------------------------------------
orthology (Orthology inference)
------------------------------------

A prerequisite of gene-based phylogenomics is to establish orthologous relationships and identify a set of suitable genes (usually single-copy orthologs). phylociraptor currently uses the BUSCO approach to search for complete single-copy orthologs (genes which are present with only a single copy in eah genome) in the specified set of assemblies. BUSCO is well established and widely used in contemporary genomic analyses. Phylociraptor will automatically run BUSCO on the set of specified genomes, extract single-copy genes and combine them into individual files for each BUSCO gene. This step is invoked by running :bash:`phylociraptor orthology`.  
After this step you will see a new directory :bash:`results/busco_sequences` which contains a file for each BUSCO gene. Each gene file contains all the sequences of that gene which were found in the set of specified genomes. This selection is based on a table produced by phylocirpator which is found in :bash:`results/busco_table`. 
There are many additional approaches to infer orthology and in the future we plan to add some of them to phylociraptor.

For additional information on the inner workings of BUSCO please go `here <https://busco-archive.ezlab.org/>`_.

--------------------------------------
filter-orthology (Filter orthologs)
--------------------------------------

When orthology inferrence has successfully finished (after running :bash:`phylocirpator orthology`) it is necessary to filter the results. Due to a number of reasons (eg. low assembly quality, poor representation of taxonomic group in BUSCO set, etc.)  it can happen that BUSCO performance is low and we therefore want to remove samples with too-low performance from downstream analyses. To do this, phylociraptor offers the :bash:`phylociraptor filter-orthology` runmode. Here phylociraptor will perform two filtering steps, which can be set in the :bash:`config.yaml` file under the section :bash:`filtering` (see also the corresponding section above).

1. Remove samples with low overall BUSCO performance based on the percentage of found complete single-copy orthologs. (sample-based filtering)
2. Remove BUSCO genes which have only been found in a small number of samples. (gene-based filtering)

For the first filtering step you need to specify a number between 0 and 1. 0 means include all species and 1 means include only the samples for which all BUSCO genes were found in a single copy. Both scenarios are unrealistic. On the one hand, including also species for which only a very small number of single copy orthologous genes have been found could influence phylogenetic placement and quality of the tree. On the other hand, by using 1 you assume that BUSCO was able to identify each BUSCO gene in each sample, which is very unlikely as well.  
As you can see, filtering is a trade-off. Increasing this value will lower the number of samples included in the analysis, while keeping it too low could impact phylogenetic placement.  

The second filtering step is also important. For each gene used in a phylogenomic analysis you will want a reasonably high number of sequences from different samples and a small number of missing data. The number you use here should be between 3 (the minimum number of sequences you need to calculate a phylogeny) and the number of samples you have in your dataset. 

-------------------------------------
align (Create and trim alignments)
-------------------------------------

During this step phylociraptor creates individual alignments for each recovered single-copy orthologous gene. Alignment is currently done using `mafft`_ but we plan to add additional aligners in the future. According to the setting specified in the :bash:`config.yaml` file (see above) mafft will be run for each gene. Each alignment will be placed in the directory `results/alignments`. Individual alignments are in FASTA format and can be downloaded and inspected.

The corresponding runmode of phylociraptor is :bash:`phylociraptor align`

.. note::

   Alignment and trimming are executed together in the runmode :bash:`-m align` . 

After alignments have been generated, each alignment is trimmed to filter out positions and sequences (depending on the selected trimming strategy).Phylociraptor supports `trimal`_ and AliScore/Alicut for alignment trimming.

-----------------------------------
filter-align (Filter alignments)
-----------------------------------

When alignment and trimming is finished, phylociraptor provides an additional step to filter alignments by running :bash:`phylociraptor filter-align` .

1. First, alignments can be filtered based on the number of parsimony informative sites in the alignment. This value can be set in the :bash:`config.yaml` file.
2. Second, alignments can be filtered again for the number of sequences they contain. This step is similar to the filtering down in :bash:`phylociraptor filter-orthology`. It is necessary to do this twice, since the number of sequences in each alignment could have changed after trimming.

phylociraptor will output filtered alignments to :bash:`results/filtered_alignments` . The files in this folder will be used for tree calculation and modeltesting.

-------------------------------------
model (Substitution model testing)
-------------------------------------



-------------------------------------
tree (Calculate ML phylogenies)
-------------------------------------

-----------------------------------------
speciestree (Calculate species trees)
-----------------------------------------

------------------------------------------
njtree (Calculate NJ tree)
------------------------------------------


