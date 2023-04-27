function retval = isOctave
  persistent cacheval;  % speeds up repeated calls

  if isempty (cacheval)
    cacheval = (exist ("OCTAVE_VERSION", "builtin") > 0);
  end

  pkg load netcdf
  pkg load statistics
  graphics_toolkit('gnuplot')

  retval = cacheval;
end