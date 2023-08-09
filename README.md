# AMPSCZ Feature Extraction Utility for Daily Audio Journals

Supplement to AMPSCZ diary data flow code, for extraction of OpenSMILE features on the designated AV processing server(s). Work in progress.

### Purpose

Because raw audio data cannot be transfered beyond the central sites' (ProNET and PRESCIENT) data aggregation servers, for any audio datatype we need base feature computation to occur as part of the core project infrastructure; extracted features can then be transferred downstream along with raw data of other types. However the data aggregation servers where early stage QC and file accounting occur are not equipped for ongoing computationally intensive feature extraction, so for each central aggregation server an AV processing server will be used to run audio/video feature operations. This repo is intended to be installed on said AV processing servers for analysis of the daily journal (aka diary) datatype. 

It is a separate code base because it needs to be run in parallel on a different server, but it is ultimately just a piece of the diary processing/monitoring infrastructure that can primarily be found in the [daily_journal_dataflow_qc repository](https://github.com/dptools/daily_journal_dataflow_qc)

### Remaining TODOs

1. Work with IT to test and then finalize launch of this extraction script for ProNET (see opensmile_feature_extraction_script-pronet.sh).
2. Finish this README, including documentation of specific extracted features and instructions/dependencies for installation on other AMPSCZ (or similar project) AV servers.
3. Add cleanup and monitoring of completed acoustic feature extraction to the main daily_journal_dataflow_qc code, and update those docs accordingly.
4. Set up this same code to run on designated PRESCIENT AV server.
