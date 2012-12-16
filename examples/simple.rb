require_relative '../lib/grafikon'

a = (1..6).map{|x| [x,x]}
b = (1..6).map{|x| [x,x**1.5]}

puts(Grafikon::Chart::Line.new do
  size :fill, '8cm'
  add a, :title => 'linear', :mark => :x
  add b, :title => 'linear-and-half', :color => :gray
end.pgfplots)

puts(Grafikon::Chart::Line.new do
  axes 'x-value', 'y-value'
  size :fill, '8cm'
  add_diff a, b
end.pgfplots)

c = Grafikon::Chart::Bar.new do
  axes 'x-value', 'y-value'
  size :fill, '8cm'
end
c.add [['a',1],['b',2]]
c.add [['b',1.5],['c',2.5]]
puts c.pgfplots