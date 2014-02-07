require 'filemagic'

class ApeFile

  attr_reader :ape_filename, :cue_filename

  def initialize(ape_filename,cue_filename=nil)
    return nil if File.extname(ape_filename.downcase)!='.ape'
    @ape_filename=ape_filename
    if !cue_filename.nil?
      @cue_filename=cue_filename
    else
      fname=@ape_filename.sub(/.ape$/,'.cue')
      if !File.exists?(fname)
        cuefiles=Dir.glob(File.join(File.dirname(@ape_filename),'*.cue'), File::FNM_CASEFOLD)
        if cuefiles.size==1
          @cue_filename=cuefiles.first
        else
          # puts "file cue non trovato per #{File.basename(@ape_filename)}"
          @cue_filename=nil
        end
      else
        @cue_filename=fname
      end
    end
    self
  end

  def valid_cue_file?
    return nil if self.cue_filedata.nil?
    begin
      ext=File.extname(cue_head_block('FILE').downcase)
    rescue
      puts "ape_file (#{self.ape_filename}) valid_cue_file? => #{$!}"
      return false
    end
    ext=='.ape' ? true : false
  end

  def cue_filedata
    return nil if @cue_filename.nil?
    return @cue_filedata if !@cue_filedata.nil?
    data=File.read(@cue_filename)
    filemagic=FileMagic.mime.file(@cue_filename)
    if !(filemagic =~ /charset=(.*) ?/).nil?
      # puts "charset: #{$1}"
      begin
        data.encode!('utf-8',$1) if $1!='utf-8'
      rescue
        puts "cue_filedata => #{$!} (file #{@cue_filename}"
        return nil
      end
    end
    @cue_filedata=data.gsub("\r",'').gsub('  INDEX 0','  INDEX0').gsub("\t",' ')
  end

  def cue_head_block(tag=nil)
    return nil if self.cue_filedata.nil?
    data=self.cue_filedata.split("\n  TRACK")
    return nil if data.size < 2
    data=data.first
    if tag.blank?
      data
    else
      # puts "estrazione tag #{tag}"
      reg=Regexp.new("^#{tag}")
      res=''
      data.split("\n").each do |l|
        if reg =~ l
          if /"(.*)"/ =~ l
            res=$1
            break
          end
        end
      end
      res
    end
  end

  # NB: trackblock se !nil deve essere un elemento dell'array che si ottiene
  # con cue_tracklist_blocks, tipo questo:
  # 03 AUDIO
  #   TITLE "Couperin"
  #   PERFORMER "Elio Amato, piano; Alberto Amato, double bass; Loris Amato, drums"
  #   INDEX 00 08:31:43
  #   INDEX 01 08:33:42
  def get_track_number(trackblock=nil)
    if trackblock.blank?
      n=self.tags_from_ape['tracknumber'].to_i
    else
      n=trackblock.to_i
    end
    n==0 ? 'nil' : n
  end

  def cue_tracklist
    d=self.cue_tracklist_blocks
    return [] if d.nil?

    album_title=self.cue_head_block('TITLE')
    album_performer=self.cue_head_block('PERFORMER')

    trlist=[]
    d.each do |t|
      tracknumber=self.get_track_number(t)
      # puts "tracknumber: #{tracknumber}"
      lines=t.split("\n")
      lines.shift
      tracks={}
      tracks['tracknumber']=tracknumber
      lines.each do |e|
        if /(TITLE|PERFORMER|INDEX00|INDEX01) (.*)/ =~ e
          label=String.new($1)
          val=$2.gsub('"','')
          eval %Q{tracks[label.downcase]=val}
        end
      end
      # puts "tracks: #{tracks.keys}"
      tracks['album']=album_title
      tracks['album']='[missing title]' if tracks['album'].blank?
      trlist << tracks
    end
    trlist
  end

  def cue_tracklist_blocks
    return nil if self.cue_filedata.nil?
    data=self.cue_filedata.split("\n  TRACK")
    return nil if data.size < 2
    data.shift
    data
  end

  def tags_from_ape
    {}
  end

  def sox_split_info
    return nil if !self.valid_cue_file?
    def timediff(a,b)
      a_min,a_sec=a
      b_min,b_sec=b
      min_diff=b_min.to_i - a_min.to_i
      sec_diff=b_sec.to_i - a_sec.to_i
      if sec_diff<0
        sec_diff+=60
        min_diff-=1
      end
      # puts "timediff #{a_min}:#{a_sec} - #{b_min}:#{b_sec} => #{min_diff}:#{sec_diff}"
      format "%02d:%02d", min_diff,sec_diff
    end
    prectime=''
    cnt=0
    tracktime=nil
    soxtrims=[]
    self.cue_tracklist.each do |t|
      tt=t['index01']
      next if tt.blank?
      tt=tt.split(':')[0..1]
      tracktime=tt
      if !prectime.blank?
        td=timediff(prectime,tt)
        # puts "#{cnt} #{prectime.inspect} -- #{tt.inspect} => #{td}"
        # soxtrims << [(format "%02d",cnt), prectime.join(':'), td]
        soxtrims << [cnt, prectime.join(':'), td]
      end
      prectime=tt
      cnt+=1
    end
    # soxtrims << [(format "%02d",cnt), tracktime.join(':'), nil]
    soxtrims << [cnt, tracktime.join(':'), nil]
    # puts "last tracktime start: #{tracktime.join(':')}"
    #soxtrims.each do |st|
    #  puts "trim: #{st.inspect}"
    #end
    soxtrims
  end

  def tracklist_xml(colloc,folder)
    doc = REXML::Document.new("<tracklist></tracklist>")
    doc.root.attributes['colloc']=colloc
    doc.root.attributes['folder']=folder
    if self.valid_cue_file?
      self.cue_tracklist.each do |t|
        e=REXML::Element.new('title')
        e.text=t['title'].gsub!('\\', '')
        e.attributes['position']=t['tracknumber']
        e.attributes['index00']=t['index00']
        e.attributes['index01']=t['index01']
        doc.root.add_element(e)
      end
    else
      return nil
    end
    doc.root.to_s
  end

end
