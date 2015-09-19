# lytro_tools
collection of tools for working with Lytro files

# usage
````
lua split_lfx.lua filename [outdir]
    filename : *.(lfp|lfr|lfx)
    outdir   : deafult is current dir; output directory must be present
````
````
lua convert_raw_to_8bit.lua filename [bitdepth [pgm]]
    filename : (imageRef|modulationDataRef).bin from splitter
    bitdepth : 8, 10 (default), 12, 16; 10 - Illum, 12 - first model
    pgm      : false (default), true; add PGM-header to raw data

    a new file (.raw|.pgm) is created next to the original.
````
````
lua convert_depth_to_8bit.lua filename [ascii]
    ascii    : false (default), true; make ascii PGM, otherwise binary

    a new file (.pgm) is created next to the original.
````
