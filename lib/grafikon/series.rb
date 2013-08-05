module Grafikon
  module Series
    class Generic
      attr_accessor :data, :mark, :color, :pattern, :line_width, :mark_size, :axis
      attr_writer :title
    
      def initialize(chart)
        @title = nil
        @chart = chart
        @color = nil
        @pattern = nil
        @mark = nil
        @line_width = 1
        @data = []
        @x_error_bars = nil
        @y_error_bars = nil
        @axis = :primary
      end
      
      def title
        @title || '---'
      end
        
      def check
        Array === @data or raise ArgumentError, "Series data have to be an array"
        @data.each do |point|
          Array === point or raise ArgumentError, "Series data point has to be an array"
          point.size == 2 or point.size == 4 or raise ArgumentError, "Series data point has to be an array with 2 or 4 elements"
        end
        if Symbol === @color
          @color = Grafikon::Color::name(@color)
        end
        if Symbol === @mark
          @mark = Grafikon::Mark::new(@mark)
        end
      end
      
      def gnuplot_options
        opts = []
        
        if @line_width && @line_width > 0 && @mark && !@mark.none?
          opts << "with linespoints"
        elsif @line_width && @line_width > 0
          opts << "with lines"
        else
          opts << "with points"
        end
        
        opts << "lc #{@color.as_gnuplot}"
        opts << "pt #{@mark.as_gnuplot}" unless @mark.none?
        opts << "title \"#{@title}\""  
        opts << "axes x1y2" if @axis == :secondary    
        
        opts * " "
      end
      
      def csv_temp_file
        require 'tempfile'

        file = Tempfile.new('series_csv')
        
        @data.each do |x,y|
          file.write "%.5e %.5e\n" % [x,y]
        end
        
        file.close
        
        file
      end

      def x_values
        @data.map{|x| x[0]}
      end
          
      def y_values
        @data.map{|x| x[1]}
      end
      
      def stepify
        return if @data.empty?
        new_data = []
        (0...@data.size).each do |i|
          if i > 0
            new_data << [(@data[i-1][0] + @data[i][0])/2.0,@data[i][1]]
          end
          new_data << @data[i].dup
          if i+1 < @data.size
            new_data << [(@data[i+1][0] + @data[i][0])/2.0,@data[i][1]]
          end          
        end
        @data = new_data
      end
      
      def prune(n, opts)
        return if @data.empty?
        opts[:remove_outliers] = false unless opts.has_key?(:remove_outliers)
        
        xmin, xmax = x_values.min, x_values.max
        new_data = []
        (0...n).each do |i|
          x1 = xmin + (xmax - xmin) / n *  i 
          x2 = xmin + (xmax - xmin) / n * (i+1) 
          y  = @data.select{|w| x1 <= w[0] and w[0] <= x2}.map{|w| w[1]}
          unless y.empty?
            if opts[:remove_outliers] and y.size > 1
              avg = y.inject(0.0){|s,x| s+x} / y.size
              std = (y.inject(0.0){|s,x| s + (x-avg)**2} / (y.size - 1)) ** 0.5
              newy = y.select{|w| (w - avg).abs < 2*std}
              y = newy unless newy.empty?
            end
            unless y.empty?
              new_data << [x1, y.min] unless opts[:select] == :max
              new_data << [x2, y.max] unless opts[:select] == :min
            end
          end
        end
        @data = new_data
      end
      
    end
    
    class Line < Generic
      
      def initialize(chart)
        super(chart)
        @connect = :smooth
      end
      
      def connect=(x)
        [:straight, :smooth, :const].include?(x) or raise ArgumentError, "Invalid connect [#{x}]"
        @connect = x
      end
      
      def y_error_bars(opts = {})
        @y_error_bars = {:measure => :fixed, :direction => :both}.merge(opts)
      end
      
      def check
        super
        @data = @data.sort_by{|x| x.first}
      end
      
      def as_pgfplots
        check
        options = []
        
        options << "mark=#{@mark.as_pgfplots}"
        options << "color=rgbcolor%04d%04d%04d" % [color.r*1000, color.g*1000, color.b*1000]

        if @line_width and @line_width > 0
          options << "line width=#{@line_width}pt"
        else
          options << 'only marks'
        end

        if @mark_size and @mark_size > 0
          options << "mark size=#{@mark_size}pt"
        end
                
        
        case @connect
        when :smooth
          ""
        when :straight
          options << "straight plot"
        when :const
          options << "const plot"
        end
        
        eb = ""
        if @y_error_bars
          d = case @y_error_bars[:direction]
          when :minus
            'minus'
          when :plus
            'plus'
          when :both
            'both'
          else
            raise "Invalid y error bar direction [#{@y_error_bars[:direction]}]"
          end
          eb = %{[error bars/.cd,y dir=#{d}]}
        end
        
        if @y_error_bars or @x_error_bars
          s = %{
            \\addplot[#{options * ','}] plot#{eb} coordinates {
              #{@data.map{|q| "(%s,%.5e) +- (%f,%.5e)" % [q[0].to_s, q[1].to_f, q[2].to_f, q[3].to_f]} * "\n"}
            };        
          }
        else
          s = %{
            \\addplot[#{options * ','}] plot#{eb} coordinates {
              #{@data.map{|q| "(%s,%.5e)" % [q[0].to_s, q[1].to_f]} * "\n"}
            };        
          }
        end
        s
      end
    
    end
    
    class Bar < Generic
      
      def as_pgfplots
        check
        p = "color=rgbcolor%04d%04d%04d" % [color.r*1000, color.g*1000, color.b*1000]
        p = "," + @pattern.as_pgfplots if @pattern
        s = %{
          \\addplot[color=black,fill=tempcolor#{self.object_id}#{p}] coordinates {
            #{@data.map{|q| "(%s,%.5e)" % [q[0].to_s, q[1].to_f]} * "\n"}
          };        
        }
        s
      end
    
    end
  end
end