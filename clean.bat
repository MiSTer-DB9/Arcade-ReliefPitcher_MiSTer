@echo off
rmdir /s /q db
rmdir /s /q incremental_db
rmdir /s /q output_files
del build_id.v
del c5_pin_model_dump.txt
del PLLJ_PLLSPE_INFO.txt
del /s *.qws
del /s *.bak
