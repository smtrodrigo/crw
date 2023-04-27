FROM docker.io/gnuoctave/octave:6.2.0

RUN mkdir /m_map
RUN wget http://www.eos.ubc.ca/~rich/m_map1.4.tar.gz
RUN tar xzvf /m_map1.4.tar.gz

RUN apt-get update && apt-get install -y \
  octave-netcdf \
  octave-statistics \
  && rm -rf /var/lib/apt/lists/*

