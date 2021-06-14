## wmi exporter installation

wmi exporter expose windows server metrics in http://%COMPUTERNAME%:9182/metrics end point and it is running as a service in the target windows VM.

wmi exporter configuration can be controlled by setting below set of parameters.

ENABLED_COLLECTORS
LISTEN_ADDR
LISTEN_PORT
METRICS_PATH
TEXTFILE_DIR
EXTRA_FLAGS

## Installation Guide

1. Unzip the wmi_exporter.zip 
2. Set the ENABLED_COLLECTORS , TEXTFILE_DIR , TOOL variables in 1. install_wmi_exporter.cmd according to your test

    set ENABLED_COLLECTORS=os,cpu,iis,cs,logical_disk,net,system,textfile
    set TEXTFILE_DIR="C:/custom_metrics"
    TOOL=wmi_exporter-0.9.0-amd64.msi

3. Need to run this tool alongside with wmi_exporter-%version%.msi , in the same folder
4. Run 1. install_wmi_exporter.cmd
5. To verify the service is running , run 2. verify_wmi_exporter file

    wmi exporter is running on http://%COMPUTERNAME%:9182/metrics url

6. to remove wmi expoerter , run remove_wmi_exporter.cmd
7. Custom metrics should be directed to a .prom file (ex: custom_metrics.prom) inside TEXTFILE_DIR path



