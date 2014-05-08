# -*- mode: ruby;-*-

desc 'Legge il file xml con i dati del sistema audio e estrai opac_id,bm_id,primary_id'

# require 'rexml/document'
require 'libxml'
include LibXML


class Parser
  include XML::SaxParser::Callbacks 
  
  def initialize
    # Constructor
  end
 
  def on_start_element(element, attributes)  
    if element.to_s=='NewDataSet'
      # puts "Inizio file"
    end
    if element.to_s=='tFiles'
      # puts "Inizio record"
      @hdata={}
    end
    @read_string = '' if element=='primary_id'
    @read_string = '' if element=='bm_id'
    @read_string = '' if element=='opac_id'
  end
  def on_cdata_block(cdata)
    # This event is fired when a CDATA block is found.
  end
  def on_characters(chars)
    # This event is fired when characters are encountered between the start and end of an element.
    @read_string = @read_string + chars if !@read_string.nil?
  end
 
  def on_end_element(element)
    if element.to_s=='tFiles'
      # puts "Fine record"
      if (@hdata['bm_id']=='-1') and (@hdata['opac_id']=='-1')
        # puts @hdata.inspect
        return
      else
        puts "#{@hdata['primary_id']},#{@hdata['opac_id']},#{@hdata['bm_id']}"
      end
    end
    return if @read_string.nil?
    # puts "end #{element} (@read_string: #{@read_string})"
    @hdata[element]=@read_string
    @read_string = nil
  end
  
end


task :read_avplayer_data => :environment do
 
  # xmlfile='/tmp/AvPlayerShort.xml'
  xmlfile='/mnt/r2/Data/db/AvPlayer/AvPlayer.xml'
  # doc=REXML::Document.new(File.read(xmlfile))
  # puts "doc: #{doc.root.elements.size}"
  
  parser = XML::SaxParser.file(xmlfile)
  parser.callbacks = Parser.new
  parser.parse
end

