# r-ruby line plot examples

require 'r-ruby'

## PLOT 1 - a simple line plot with only required options, and one series
plot = RRuby::LinePlot.new({
  :path => 'plot1.bmp', # output file name/path
  :type => :bmp})       # output file type
plot.add_series(
  [1, 3, 2, 5, 4],      # array of y-values
  nil)                  # no x-values means it will follow array index
plot.plot               # plot the data. Returns the R execution output so put a 'puts'
                        #  in front to see the generated code


## PLOT 2 - more than one series, with defined x-values, and colors
plot = RRuby::LinePlot.new({:path => 'plot2.bmp', :type => :bmp})
plot.add_series([1, 3, 2, 5, 4], nil, 
                {:color => :red})   # options hash with color specified as symbol
plot.add_series([1, 3, 2, 5, 4],        # another series
                [2, 6, 3, 8, 1],        # x-values specified
                {:color => '#30F030'})  # color specified as HTML-like hexadecimal
plot.add_series([1, 3], [1, 8], 
                {:color => [0.2, 0.2, 1]}) # color specified as an array of 3 numeric values within [0, 1]
plot.plot


## PLOT 3 - larger output image and line styling
plot = RRuby::LinePlot.new({:path => 'plot3.bmp', :type => :bmp, 
                           :size => [800, 600]}) # height, width of output image in pixels
plot.add_series([1, 3, 2, 5, 4], nil, {:color => :red, 
                :line_weight => 2,      # line thickness (1 is default)
                :line_type => :dotted}) # line type (solid|dotted|dashed - default is solid)
plot.add_series([1, 3, 2, 5, 4], [2, 6, 3, 8, 1], {:color => '#30F030', :line_weight => 4})
plot.add_series([1, 3], [1, 8], {:color => [0.2, 0.2, 1], :line_weight => 8, :line_type => :dashed})
plot.plot


## PLOT 4 - point indicators, titles, margin tweaks, and domain/range settings
plot = RRuby::LinePlot.new({:path => 'plot4.bmp', :type => :bmp, :size => [800, 600], 
                           :margin => [5, 5, 5, 3], # margin size [bottom, left, top, right]
                           :x_range => [-1, 9],     # specify x range (default is :auto)
                           :y_range => [0, 8]})     # specify y range (default is :auto)
plot.add_series([1, 3, 2, 5, 4], nil, {:color => :red, :line_weight => 2, :line_type => :dotted, 
                :point_type => 'O'}) # point type as character
plot.add_series([1, 3, 2, 5, 4], [2, 6, 3, 8, 1], {:color => '#30F030', :line_weight => 4, 
                :point_type => 5}) # point type by number (0-25)
plot.add_series([1, 3], [1, 8], {:color => [0.2, 0.2, 1], :line_weight => 5, :line_type => 
                :dashed, :point_type => 19})
plot.add_title(         # add a title
  :top,                 # title position (top,x,y)
  'Top Title',          # tile text
  {:color => :black,    # options hash with color
    :font_scale => 4})  # and text size multiplier (default is 1)
plot.add_title(:y, 'y title', {:color => :orange, :font_scale => 2}) # another title for the y axis
plot.add_title(:x, 'x title', {:color => :purple})                   # another title for the x axis
plot.plot


## PLOT 5 - automatic legend, background/foreground colors
plot = RRuby::LinePlot.new({:path => 'plot5.bmp', :type => :bmp, :size => [800, 600], 
                           :margin => [5, 5, 5, 3], :x_range => [-1, 9], :y_range => [0, 8],
                           :background => :pink,            # background color
                           :foreground => [0.1, 0.2, 0.3],  # foreground color
                           :auto_legend => true})           # generate a legend automatically
plot.add_series([1, 3, 2, 5, 4], nil, {:color => :red, :line_weight => 2, 
                :line_type => :dotted, :point_type => 'O', 
                :name => 'fun series!'}) # add a name to the series
plot.add_series([1, 3, 2, 5, 4], [2, 6, 3, 8, 1], {:color => '#30F030', :line_weight => 4, 
                :point_type => 5, 
                :name => 'ugly series!'}) # add a name to the series
plot.add_series([1, 3], [1, 8], {:color => [0.2, 0.2, 1], :line_weight => 5, :line_type => 
                :dashed, :point_type => 19}) # specifically don't add a name to the series (automatically named)
plot.add_title(:top, 'Top Title', {:color => :black, :font_scale => 4})
plot.add_title(:y, 'y title', {:color => :orange, :font_scale => 2})
plot.add_title(:x, 'x title', {:color => :purple})
plot.plot
