# lytro_tools
collection of tools for working with Lytro files

# usage
````
lua split_lfx.lua filename [outdir]
    filename : *.(lfp|lfr|lfx)
    outdir   : deafult is current dir; output directory must be present
````
````
lua convert_raw_to_8bit.lua filename width height bitdepth
    filename : (imageRef|modulationDataRef).bin from splitter
    bitdepth : 8, 10 (Illum), 12 (v1), 16
````
````
lua convert_depth_to_8bit.lua filename
    filename : depthMap*.map from splitter
````
````
lua convert_hotpixel_to_1bit.lua filename width height [negative]
    filename : hotPixelRef.bin from splitter
    negative : make white background
````
all new files (*.pgm) is created next to the original.
