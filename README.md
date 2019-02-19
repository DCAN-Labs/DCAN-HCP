# DCAN-HCP Pipelines 

This repository is the DCAN labs' modified HCP Pipelines for the processing of functional MRI images.

The original HCP Pipelines is a set of tools (primarily, but not exclusively,
shell scripts) for processing MRI images for the [Human Connectome Project][HCP], 
as outlined in [Glasser et al. 2013][GlasserEtAl].  **The original pipeline
software is available [here](https://github.com/Washington-University/HCPpipelines)**

In particular, the DCAN labs repository includes several modifications of primary shell 
scripts for processing functional MRI data.

The changes include:
- updating the nonlinear registration tool to [ANTs](https://github.com/ANTsX/ANTs)
- using denoising and N4BiasCorrection to increase consistency over extreme noise or bias in anatomical scans
- optional processing with no T2-weighted image
- adjusting the order of some image processing operations
- several additional options for processing

This is the backend component for the processing of data. It is not designed for direct use as a user interface. For the pipeline interface in the form of a dockerized bids application, please refer to [the official application repository](https://github.com/DCAN-Labs/dcan-fmri-pipelines).


<!-- References -->

[HCP]: http://www.humanconnectome.org
[GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
