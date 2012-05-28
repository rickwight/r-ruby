module RRuby
  module Helpers
    def self.assert(obj, klass, name)
      unless klass.kind_of?(Array)
        klass = [klass]
      end
      klass.each do |k|
        if obj.kind_of?(k)
          return
        end
      end
      raise(TypeError, "#{name} must be of type #{klass.join(',')}, but was #{obj.class}")
    end

    def self.assert_each(arr, klass, name)
      assert(arr, Array, name)
      arr.each_with_index do |a, i|
        assert(a, klass, name << "[#{i}]")
      end
    end

    def self.assert_equal(obj, expectation, name)
      unless obj == expectation
        raise(RuntimeError, "Expected #{name} to be #{expectation.inspect}, but got #{obj.inspect}")
      end
    end

    def self.assert_include(obj, possible_values, name)
      unless possible_values.include?(obj)
        if possible_values.kind_of?(Range)
          possible_values = [possible_values.first, possible_values.last]
        end
        raise(RuntimeError, "Expected #{name} to be within or one of {#{possible_values.join(',')}}, " <<
              "but got #{obj.inspect}")
      end
    end
  end

  module RObjects
    # Classes that generate parsable R constructs. Don't use these classes directly.
    class Error < RuntimeError; end

    class Base
      def initialize(input)
        @input = input
        validate
      end

      def validate
      end

      def assert(obj, klass, name)
        Helpers.assert(obj, klass, "#{self.class}#{name}")
      end

      def assert_each(arr, klass, name)
        Helpers.assert_each(arr, klass, "#{self.class}#{name}")
      end

      def assert_equal(obj, expectation, name)
        Helpers.assert_equal(obj, expectation, "#{self.class}#{name}")
      end

      def assert_include(obj, possible_values, name)
        Helpers.assert_include(obj, possible_values, "#{self.class}#{name}")
      end
    end

    class Arg < Base
      def validate
        types = [Array, Numeric, Symbol, String, TrueClass, FalseClass, Base]
        assert(@input, types, '@input')
      end

      def to_r
        if @input.kind_of?(Array)
          if @input.length == 1
            Arg.new(@input.first).to_r
          else
            "c(#{@input.map{|a| Arg.new(a).to_r}.join(', ')})"
          end
        elsif @input.kind_of?(Numeric)
          @input.to_s
        elsif @input.kind_of?(Symbol)
          "'#{@input}'"
        elsif @input.kind_of?(String)
          "'#{@input}'"
        elsif @input.kind_of?(TrueClass)
          'TRUE'
        elsif @input.kind_of?(FalseClass)
          'FALSE'
        elsif @input.kind_of?(Base)
          @input.to_r
        end
      end
    end

    class Function < Base
      def validate
        assert(@input, Hash, 'input')
        assert(@input[:name], [String, Symbol], '@input[:name]')
        if @input[:positional]
          assert(@input[:positional], Array, '@input[:positional]')
        end
        if @input[:keyed]
          assert(@input[:keyed], Hash, '@input[:keyed]')
        end
      end
      
      def to_r
        name = @input[:name]
        positional = @input[:positional]
        keyed = @input[:keyed]
        s = "#{name}("
        if positional
          s << "#{positional.map{|a| Arg.new(a).to_r}.join(', ')}"
          if keyed and not keyed.empty?
            s << ', '
          end
        end
        arr = Array.new
        if keyed
          keyed.each do |key, val|
            if val.nil?
              next
            end
            arr << "#{key}=#{Arg.new(val).to_r}"
          end
          s << arr.join(', ')
        end
        s << ')'
      end
    end

    class ParameterHelper < Base
      def initialize(input)
        @positional = Array.new
        @keyed = Hash.new
        super(input)
      end

      def function_name
        raise(NotImplementedError)
      end

      def validate
        assert(@input, Hash, '@input')
        translate_inputs
      end

      def parameter_map
        Hash.new
      end

      def translate_inputs
        parameter_map.each do |key, opts|
          value = nil
          p @input[key]
          if (not @input[key].nil?) or opts[:required] or opts[:pos]
            make_array = false
            p @input[key]
            if @input[key].kind_of?(Array)
              if opts[:type] == Color and @input[key].first.kind_of?(Numeric) and @input[key].length == 3
                make_array = true
              end
            else 
              make_array = true
            end
            if make_array
              @input[key] = [@input[key]]
            end
            p @input[key]
            if opts[:array_type]
              @input[key] = opts[:type].new(@input[key])
            else
              @input[key].each_with_index do |input, index|
                if opts[:auto_cast]
                  if not input.kind_of?(opts[:type])
                    @input[key][index] = opts[:type].new(input)
                  end
                else
                  assert(@input[key][index], opts[:type], "@input[#{key}]")
                end
              end
              if @input[key].kind_of?(Array) and not opts[:array_type]
                if @input[key].length == 1
                  @input[key] = @input[key].first
                elsif @input[key].empty?
                  @input[key] = nil
                end
              end
            end
            value = @input[key]
          elsif opts[:default]
            value = opts[:type].new(opts[:default])
          end
          unless value.nil?
            if opts[:pos]
              @positional[opts[:pos]] = value
            elsif opts[:key]
              @keyed[opts[:key]] = value
            end
          end
        end
      end

      def to_r
        pos = @positional
        if @positional.empty?
          pos = nil
        end
        key = @keyed
        if @keyed.empty?
          key = nil
        end
        Function.new({:name => function_name, :positional => pos, :keyed => key}).to_r
      end
    end

    class Abline < ParameterHelper
      def function_name
        :abline
      end

      def parameter_map
        {
          :horizontal => {:key => :h, :type => Numeric},
          :vertical => {:key => :v, :type => Numeric}
        }.merge(ParameterMaps::LineParams)
      end

      def validate
        super
        unless @input[:horizontal] or @input[:vertical]
          raise(Error, 'At least one of @input[:horizontal] or @input[:vertical] must be defined')
        end
      end
    end

    class Text < ParameterHelper
      def function_name
        :text
      end

      def parameter_map
        {
          :text => {:pos => 2, :type => String},
          :position => {:key => :pos, :type => TextPosition, :auto_cast => true},
          :offset => {:key => :offset, :type => Fixnum},
          :font_scale => {:key => :cex, :type => Numeric},
          :rotation => {:key => :srt, :type => Numeric},
          :color => {:key => :col, :type => Color, :auto_cast => true}
        }
      end

      def validate
        super
        assert(@input[:location], Array, '@input[:location]')
        if @input[:location].first.kind_of?(Array)
          @input[:location].each_with_index do |location, index|
            assert_each(@input[:location][index], Numeric, "@input[:location][#{index}]")
            assert_equal(@input[:location][index].length, 2, "@input[:location][#{index}].length")
          end
        else
          assert_each(@input[:location], Numeric, '@input[:location]')
          assert_equal(@input[:location].length, 2, '@input[:location].length')
        end
        if @input[:location].first.kind_of?(Array)
          @positional[0] = Array.new
          @positional[1] = Array.new
          @input[:location].each do |location|
            @positional[0] << location[0]
            @positional[1] << location[1]
          end
        else
          @positional[0] = @input[:location][0]
          @positional[1] = @input[:location][1]
        end
      end
    end

    class Points < ParameterHelper
      def function_name
        :points
      end
      
      def parameter_map
        ParameterMaps::LineParams.merge(ParameterMaps::XYPoints)
      end

      def validate
        super
        unless @input[:x].length == @input[:y].length
          raise(Error, '@input[:x] and @input[:y] must be of the same length')
        end
        @keyed[:type] = 'o'
      end
    end

    class Plot < ParameterHelper
      def function_name
        :plot
      end
      
      def parameter_map
        {
          :axes => {:key => :axes, :type => [FalseClass, TrueClass]}
        }.merge(ParameterMaps::LineParams
        ).merge(ParameterMaps::XYPoints
        ).merge(ParameterMaps::XYRange)
      end

      def validate
        super
        assert(@input[:x_range][0] < @input[:x_range][1], TrueClass, '@input[:x_range][0] < @input[:x_range][1]')
        assert(@input[:y_range][0] < @input[:y_range][1], TrueClass, '@input[:x_range][0] < @input[:x_range][1]')
        @keyed[:type] = 'o'
        @keyed[:ann] = false
      end
    end

    class BarPlot < ParameterHelper
      def function_name
        :barplot
      end
      
      def parameter_map
        {
          :matrix => {:pos => 0, :type => Matrix},
          :style => {:key => :beside, :type => BarStyle, :auto_cast => true},
          :color => {:key => :col, :type => Color, :auto_cast => true},
          :border_color => {:key => :borders, :type => Color, :auto_cast => true}
        }
      end
    end

    class Hist < ParameterHelper
      def function_name
        :hist
      end

      def parameter_map
        {
          :series => {:pos => 0, :type => Numeric},
          :color => {:key => :col, :type => Color, :auto_cast => true},
          :bins => {:key => :breaks, :type => Numeric} 
        }.merge(ParameterMaps::XYRange)
      end

      def validate
        super
        @keyed[:main] = String.new
        @keyed[:xlab] = String.new
        @keyed[:ylab] = String.new
      end
    end

    class Lines < ParameterHelper
      def function_name
        :lines
      end

      def parameter_map
        {
        }.merge(ParameterMaps::LineParams
        ).merge(ParameterMaps::XYPoints)
      end
    end

    class Output < ParameterHelper
      def function_name
        @input[:type].type
      end
      
      def parameter_map
        {
          :path => {:pos => 0, :type => String},
          :type => {:type => OutputType, :auto_cast => true},
          :size => {:type => OutputSize, :auto_cast => true, :array_type => true}
        }
      end

      def validate
        super
        if @input[:size] and @input[:type].type != :pdf
          @keyed[:width] = @input[:size].width
          @keyed[:height] = @input[:size].height
        end
      end
    end

    class Par < ParameterHelper
      def function_name
        :par
      end
      
      def parameter_map
        {
          :global_scale => {:key => :cex, :type => Numeric},
          :axis_font_scale => {:key => 'cex.axis', :type => Numeric},
          :axis_font_color => {:key => 'col.axis', :type => Color, :auto_cast => true},
          :background => {:key => :bg, :type => Color, :auto_cast => true},
          :foreground => {:key => :fg, :type => Color, :auto_cast => true},
          :margin => {:key => :mar, :type => Numeric}
        }
      end

      def validate
        super
        if @input[:margin]
          assert_equal(@input[:margin].length, 4, '@input[:margin].length')
        end
      end

      def to_r
        if @keyed.empty?
          '#par'
        else
          super
        end
      end
    end

    class Legend < ParameterHelper
      def function_name
        :legend
      end
      
      def parameter_map
        {
          :name => {:pos => 2, :type => String},
          :box_type => {:key => :bty, :type => BoxType, :auto_cast => true}
        }.merge(ParameterMaps::LineParams)
      end

      def validate
        super
        assert_each(@input[:position], Numeric, '@input[:position]')
        assert_equal(@input[:position].length, 2, '@input[:position].length')
        @positional[0] = @input[:position][0]
        @positional[1] = @input[:position][1]
      end
    end

    class Title < ParameterHelper
      def function_name
        :title
      end
      
      def parameter_map
        {
          :title => {:type => String, :required => true},
          :position => {:type => TitlePosition, :auto_cast => true},
          :font_scale => {:key => :cex, :type => Numeric},
          :color => {:type => Color, :auto_cast => true}
        }      
      end

      def validate
        super
        map = {
          :x => [:xlab, 'col.lab', 'cex.lab'],
          :y => [:ylab, 'col.lab', 'cex.lab'],
          :top => [:main, 'col.main', 'cex.main'],
        }
        pos, col, cex = map[@input[:position].to_r]
        @keyed[pos] = @input[:title]
        if @input[:color]
          @keyed[col] = @input[:color]
        end
        if @input[:font_scale]
          @keyed[cex] = @input[:font_scale]
        end
      end
    end

    class Matrix < ParameterHelper
      def function_name
        :matrix
      end
      
      def parameter_map
        {
          :values => {:pos => 0, :type => Numeric},
          :height => {:pos => 1, :type => Fixnum},
          :width => {:pos => 2, :type => Fixnum}
        }      
      end
      
      def validate
        super
        @keyed[:byrow] = true
      end
    end

    class Axis < ParameterHelper
      def function_name
        :axis
      end

      def parameter_map
        {
          :location => {:pos => 0, :type => AxisPosition, :auto_cast => true},
          :ticks => {:key => :at, :type => Numeric, :required => true},
          :labels => {:key => :labels, :type => String},
          :origin => {:key => :pos, :type => Numeric},
          :line_type => {:key => :lty, :type => LineType, :auto_cast => true},
          :color => {:key => :col, :type => Color, :auto_cast => true},
          :label_direction => {:key => :las, :type => LabelDirection, :auto_cast => true, :default => :parallel},
          :tick_marks => {:key => :tck, :type => TickMark, :auto_cast => true, :default => :outside}
        }
      end

      def validate
        super
        if @input[:labels] and @input[:ticks]
          assert_equal(@input[:labels].length, @input[:ticks].length, '@input[:labels]')
        end
      end
    end

    class TitlePosition < Base
      Positions = %W(x y top)

      def validate
        assert(@input, [Symbol, String], '@input')
        assert_include(@input.to_s, Positions, '@input')
      end

      def to_r
        @input.to_sym
      end
    end

    class BoxType < Base
      Map = {
        :none => 'n',
        :solid => nil
      }

      def validate
        assert(@input, [Symbol, String], '@input')
        assert_include(@input.to_sym, Map.keys, '@input')
      end

      def to_r
        Arg.new(Map[@input.to_sym]).to_r
      end
    end

    class OutputType < Base
      Types = %W(bmp jpeg png tiff pdf)

      def validate
        assert(@input, [Symbol, String], '@input')
        assert_include(@input.to_s, Types, '@input')
      end

      def type
        @input.to_sym
      end
    end

    class OutputSize < Base
      SizeRange = (10..10000)

      def validate
        assert_each(@input, Fixnum, '@input')
        assert_equal(@input.length, 2, '@input.length')
        assert_include(@input[0], SizeRange, '@input[0]')
        assert_include(@input[1], SizeRange, '@input[1]')
      end

      def width
        @input[0]
      end

      def height
        @input[1]
      end
    end

    class PointType < Base
      def validate
        assert(@input, [NilClass, Fixnum, Symbol, String], '@input')
        if @input == :none
          @input = '.'
        elsif @input.kind_of?(Fixnum)
          assert_include(@input, (0..25), '@input')
        else
          assert_include(@input.to_s, %W(* . o O 0 + - | % #), '@input')
        end
      end

      def to_r
        Arg.new(@input).to_r
      end
    end

    class LineWeight < Base
      def validate
        assert(@input, Fixnum, '@input')
        assert_equal(@input > 0, true, '@input > 0')
      end

      def to_r
        Arg.new(@input).to_r
      end
    end

    class Color < Base
      def validate
        assert(@input, [Array, String, Symbol], '@input')
        if @input.kind_of?(Array)
          assert_equal(@input.length, 3, '@input.length')
          assert_each(@input, Numeric, '@input')
        end
      end

      def to_r
        if @input.kind_of?(Array)
          Function.new({:name => :rgb, :positional => @input[0..2]}).to_r
        else
          Arg.new(@input).to_r
        end
      end
    end

    class SimpleMap < Base
      def map
        Hash.new
      end

      def validate
        assert(@input, [Symbol, String], '@input')
        assert_include(@input.to_sym, map.keys, '@input')
      end

      def to_r
        Arg.new(map[@input.to_sym]).to_r
      end
    end

    class BarStyle < SimpleMap
      def map
        {
          :stacked => true,
          :grouped => nil
        }
      end
    end

    class TextPosition < SimpleMap
      def map
        {
          :below => 1,
          :left => 2,
          :above => 3,
          :right => 4
        }
      end
    end

    class AxisPosition < SimpleMap
      def map
        {
          :bottom => 1,
          :left => 2,
          :top => 3,
          :right => 4
        }
      end
    end

    class LineType < SimpleMap
      def map
        {
          :none => 0,
          :solid => 1,
          :dashed => 2,
          :dotted => 3
        }
      end
    end

    class LabelDirection < SimpleMap
      def map
        {
          :parallel => 0,
          :perpendicular => 2
        }
      end
    end

    class TickMark < SimpleMap
      def map
        {
          :inside => 0.01,
          :outside => -0.01,
          :none => 0,
          :lines => 1
        }
      end
    end

    module ParameterMaps
      LineParams = {
        :color => {:key => :col, :type => RObjects::Color, :auto_cast => true},
        :line_type => {:key => :lty, :type => RObjects::LineType, :auto_cast => true},
        :line_weight => {:key => :lwd, :type => RObjects::LineWeight, :auto_cast => true},
        :point_type => {:key => :pch, :type => RObjects::PointType, :auto_cast => true, :default => :none},
      }
      XYPoints = {
        :x => {:pos => 0, :type => Numeric},
        :y => {:pos => 1, :type => Numeric}
      }
      XYRange = {
        :x_range => {:key => :xlim, :type => Numeric},
        :y_range => {:key => :ylim, :type => Numeric}
      }
    end
  end

  class Plot
    # Plot base class. Don't use this either.

    class Error < RuntimeError; end

    def initialize(args)
      Helpers.assert(args, Hash, 'Input args')
      @args = args
      validate_args
      @r_objs = Hash.new
      @r_lines = Array.new
      @r_order = [:output, :par, :plot, :reflines, :lines, :legends, :titles, :axes, :texts, :points]
      @r_order.each do |key|
        @r_objs[key] = Array.new
      end
      @series = Array.new
      @r_objs[:output] << RObjects::Output.new(@args)
      @r_objs[:par] << RObjects::Par.new(@args)
    end

    def validate_args
      if @args[:tmp_file]
        Helpers.assert(@args[:tmp_file], String, 'args.tmp_file')
      else
        @args[:tmp_file] = '/tmp/r-tmp-plot'
      end
      if @args[:r_path]
        Helpers.assert(@args[:r_path], String, 'args.r_path')
      else
        @args[:r_path] = 'R'
      end
    end

    def add_series(y_values, options = nil)
      Helpers.assert_each(y_values, Numeric, 'y_values')
      if options
        Helpers.assert(options, Hash, 'options')
      else
        options = Hash.new
      end
      default_options = {
        :color => :black,
        :name => "series[#{@series.length}]"
      }
      series = {
        :y => y_values,
        :options => default_options.merge(options)
      }
      @series << series
    end

    def add_title(position, title, options = nil)
      h = {:position => position, :title => title}
      if options
        h.merge!(options)
      end
      @r_objs[:titles] << RObjects::Title.new(h)
    end

    def add_legend(position, name, options)
      args = {
        :position => position,
        :name => name,
      }.merge(options)
      @r_objs[:legends] << RObjects::Legend.new(args)
    end

    def add_text(text, location, options = nil)
      if options
        Helpers.assert(options, Hash, 'options')
      end
      h = {
        :text => text,
        :location => location
      }
      if options
        h.merge!(options)
      end
      @r_objs[:texts] << RObjects::Text.new(h)
    end

    def add_refline(options)
      @r_objs[:reflines] << RObjects::Abline.new(options)
    end

    def add_line(options)
      @r_objs[:lines] << RObjects::Lines.new(options)
    end

    def add_axis(options)
      @r_objs[:axes] << RObjects::Axis.new(options)
    end

    def plot
      @r_order.each do |key|
        @r_objs[key].each do |r_obj|
          @r_lines << r_obj.to_r
        end
      end
      File.open(@args[:tmp_file], 'w') do |file|
        file.puts @r_lines.join("\n")
      end
      `#{@args[:r_path]} -f #{@args[:tmp_file]}`
    end
  end

  class Histogram < Plot
    # Generate a histogram plot
    def validate_args
      super
    end
  
    def add_series(series, options = nil)
      unless @series.empty?
        raise(Error, 'Only one series can be plotted in a histogram')
      end
      super(series, options)
    end

    def plot
      h = Hash.new
      h[:series] = @series.first[:y]
      options = @series.first[:options]
      if options
        h.merge!(options)
      end
      @r_objs[:plot] << RObjects::Hist.new(h)
      super
    end
  end

  class BarPlot < Plot
    # Generate a bar plot
    def validate_args
      super
      unless @args[:style]
        @args[:style] = :default
      end
    end

    def plot
      unless @series.length > 0
        raise(Error, 'You must add at least one series before plotting.')
      end
      seq = Array.new
      colors = nil
      borders = nil
      @series.each do |series|
        seq = seq + series[:y]
        if series[:options][:color]
          unless colors
            colors = Array.new
          end
          colors << RObjects::Color.new(series[:options][:color])
        end
        if series[:options][:border]
          unless borders
            borders = Array.new
          end
          borders << RObjects::Color.new(series[:options][:border])
        end
      end
      mat = RObjects::Matrix.new({:values => seq, :width => @series.first[:y].length, 
        :height => @series.length})
      @r_objs[:plot] << RObjects::BarPlot.new({:matrix => mat, :style => @args[:style], 
        :colors => colors, :borders => borders})
      super
    end
  end

  class LinePlot < Plot
    # Generate a line plot

    # set x_values as nil to use [0...y_values.length]
    def add_series(y_values, x_values, options = nil)
      super(y_values, options)
      if x_values
        Helpers.assert_each(x_values, Numeric, 'x_values')
        unless y_values.length == x_values.length
          raise(Error, 'x_values and y_values must have the same length')
        end
      else
        x_values = (0...y_values.length).to_a
      end
      @series.last[:x] = x_values
    end

    def plot
      unless @series.length > 0
        raise(Error, 'You must add at least one series before plotting.')
      end
      if @args[:x_range] == :auto
        @args[:x_range] = find_auto_range(:x)
      end
      if @args[:y_range] == :auto
        @args[:y_range] = find_auto_range(:y)
      end
      plot_options = {
        :x => [@series.first[:x].first], # dummy series 
        :y => [@series.first[:y].first],
        :line_type => :none,
        :point_type => :none
      }
      @r_objs[:plot] << RObjects::Plot.new(@args.merge(plot_options))
      @series.each do |series|
        @r_objs[:points] << RObjects::Points.new({:x => series[:x], :y => series[:y]}.merge(series[:options]))
      end
      @series.each do |series|
        if series[:options][:annotations]
          annotate_series(series, series[:options][:annotations], series[:options][:annotation_options])
        end
      end
      if @args[:auto_legend]
        auto_legend
      end
      super
    end

    private

    def annotate_series(series, annotations, options = nil)
      if options
        Helpers.assert(options, Hash, 'options')
      end
      pos = Array.new
      labels = Array.new
      series[:x].each_with_index do |x, i|
        y = series[:y][i]
        pos << [x,y]
        labels << annotations[i]
      end
      h = {:text => annotations, :location => pos}
      if options
        h.merge!(options)
      end
      @r_objs[:texts] << RObjects::Text.new(h)
    end

    def find_auto_range(dim)
      unless [:x, :y].include?(dim)
        raise(Error, 'dim must be one of :x or :y')
      end
      min = @series.first[dim].min
      max = @series.first[dim].max
      @series.each do |series|
        min = [series[dim].min, min].min
        max = [series[dim].max, max].max
      end
      [min, max]
    end

    def auto_legend
      names = Array.new
      colors = Array.new
      line_types = Array.new
      line_weights = Array.new
      point_types = Array.new
      @series.each do |series|
        colors << series[:options][:color]
        names << series[:options][:name]
        line_types << series[:options][:line_type]
        line_weights << series[:options][:line_weight]
        point_types << series[:options][:point_type]
      end
      
      opts = {
        :color => colors.compact,
        :line_type => line_types.compact,
        :line_weight => line_weights.compact,
        :point_type => point_types.compact,
        :box_type => :none
      }
      add_legend([@args[:x_range][0], @args[:y_range][1]], names, opts)
    end
  end
end
