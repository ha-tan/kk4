#!/usr/bin/env ruby
# -*- compile-command: "ruby -Ks kk4.rb" -*-

require 'Win32API'
require 'vr/vrcontrol'
require 'vr/vrlayout'
require 'vr/vrddrop'
require 'hpdf'

class Rectangle
  def initialize(x, y, w, h)
    @x, @y, @w, @h = x, y, w, h
  end
  attr_accessor :x, :y, :w, :h
  
  def add_xy(x, y)
    Rectangle.new(@x + x, @y + y, @w, @h)
  end

  def to_pdf_ary
    [@x - @w, @y - @h, @w, @h]
  end
end

class HPDFPage
  def draw_rt(color, rt)
    set_rgb_stroke(*color)
    rectangle(*rt.to_pdf_ary)
    stroke
  end

  def draw_text(font, size, s, rt)
    set_font_and_size(font, size)
    begin_text
    move_text_pos(rt.x, rt.y)
    show_text(s)
    end_text
  end
end

class Score
  def initialize(pdf = HPDFDoc.new)
    @pdf = pdf
    @pdf.set_compression_mode(HPDFDoc::HPDF_COMP_ALL)
    @pdf.use_jp_fonts
    @pdf.use_jp_encodings
    
    @font = @pdf.get_font('MS-Gothic', '90ms-RKSJ-V')
    @hfont = @pdf.get_font('MS-Gothic', '90ms-RKSJ-H')
    
    @csize, @cnum, @rnum, @rsep = 30, 16, 10, 35
    @title_width, @title_sep = 60, 10
    @pagenum_margin = 30
    
    @note_size, @hnote_size, @lnote_size = 16, 12, 8
    @noteex_size, @hnoteex_size = 8, 8
    @title_size, @author_size, @pagenum_size = 20, 16, 12

    @pages = []
    @col_rt = nil

    @title, @author = nil, nil
  end

  def new_page
    page = @pdf.add_page
    @pages << page
    page.set_size(HPDFDoc::HPDF_PAGE_SIZE_A4, HPDFDoc::HPDF_PAGE_LANDSCAPE)
    page.set_line_width(1)

    w = (@csize + @rsep) * @rnum + (@title_width + @title_sep)
    
    title_rt = Rectangle.new(
      page.get_width - (page.get_width - w) / 2,
      page.get_height - (page.get_height - @csize * @cnum) / 2,
      @title_width, @csize * @cnum)
    
    body_rt = Rectangle.new(
      page.get_width - (page.get_width - w) / 2 - (@title_width + @title_sep),
      page.get_height - (page.get_height - @csize * @cnum) / 2,
      (@csize + @rsep) * @rnum, @csize * @cnum)

    @col_rt = Rectangle.new(body_rt.x, body_rt.y, @csize, @csize)

    # page.draw_rt([1, 0, 0], title_rt)
    # page.draw_rt([1, 0, 0], body_rt)

    if @title
      rt1 = title_rt.add_xy(
        -@title_size,
        - (title_rt.h - @title.split(//).size * @title_size) / 6)
      page.draw_text(@font, @title_size, @title, rt1)
    end
    
    if @author
      rt2 = title_rt.add_xy(
        - (title_rt.w - @author_size),
        - (title_rt.h - @author.split(//).size * @author_size) * 5 / 6)
      page.draw_text(@font, @author_size, @author, rt2)
    end
  end

  def process(params)
    process_command(params)
    process_note(params)
    process_pagenum(params)    
  end

  def process_command(params)
    params.each do |param|
      next if param.kind_of?(NoteParam)
      case param.type
      when '$title';          @title          = param.value
      when '$author';         @author         = param.value
      when '$csize';          @csize          = param.value.to_f
      when '$cnum';           @cnum           = param.value.to_i
      when '$rnum';           @rnum           = param.value.to_i
      when '$rsep';           @rsep           = param.value.to_f
      when '$title_width';    @title_width    = param.value.to_f
      when '$title_sep';      @title_sep      = param.value.to_f
      when '$pagenum_margin'; @pagenum_margin = param.value.to_f
      when '$note_size';      @note_size      = param.value.to_f
      when '$hnote_size';     @hnote_size     = param.value.to_f
      when '$lnote_size';     @lnote_size     = param.value.to_f
      when '$noteex_size';    @noteex_size    = param.value.to_f
      when '$hnoteex_size';   @hnoteex_size   = param.value.to_f
      when '$title_size';     @title_size     = param.value.to_f
      when '$author_size';    @author_size    = param.value.to_f
      when '$pagenum_size';   @pagenum_size   = param.value.to_f
      end
    end
  end

  def process_note(params)
    i = 0
    page_notes = []
    params.each do |param|
      next if param.kind_of?(CommandParam)
      new_page if i.zero?

      rindex, cindex = i.divmod(@cnum)
      rt = @col_rt.add_xy(
        - (@csize + @rsep) * rindex - @rsep,
        - @csize * cindex)
      @pages.last.draw_rt([0.8, 0.8, 0.8], rt)

      page_notes[@pages.size - 1] ||= []
      page_notes[@pages.size - 1] << param

      i = (i < @cnum * @rnum - 1) ? i + 1 : 0
    end

    @pages.zip(page_notes) do |page, page_note|
      page_note.each_with_index do |note, i|
        rindex, cindex = i.divmod(@cnum)

        rt = @col_rt.add_xy(
          - (@csize + @rsep) * rindex - @rsep,
          - @csize * cindex)
        
        rt1 = rt.add_xy(
          - @csize / 2, 
          - (@csize - @note_size) / 2)
        page.draw_text(@font, @note_size, note.note[0], rt1)
        
        if note.note.size > 1
          rt1s = rt1.add_xy(@note_size / 2, 2)
          page.draw_text(@font, @note_size / 2, note.note[1], rt1s)
        end
        
        if note.noteex
          if note.noteex == '┌'
            rt1ex = rt.add_xy(
              - @noteex_size / 2 + 2,
              - (@csize - @noteex_size) / 2 + @noteex_size)
          else
            rt1ex = rt.add_xy(
              - @noteex_size / 2,
              - (@csize - @noteex_size) / 2)
          end
          page.draw_text(@font, @noteex_size, note.noteex, rt1ex)
        end
        
        if note.hnote
          rt2 = rt.add_xy(
            - @csize / 2, 
            - (@csize - @note_size) / 2 - @csize / 2 - 2)
          page.draw_text(@font, @hnote_size, note.hnote[0], rt2)
          
          if note.hnote.size > 1
            rt2s = rt2.add_xy(@hnote_size / 2, 2)
            page.draw_text(@font, @note_size / 2, note.hnote[1], rt2s)
          end
          
          if note.hnoteex
            if note.hnoteex == '┌'
              rt2ex = rt.add_xy(
                - @hnoteex_size / 2 + 1, 
                - (@csize - @hnoteex_size) / 2 - @csize / 2 + @hnoteex_size / 2 + 2)
            else
              rt2ex = rt.add_xy(
                - @hnoteex_size / 2, 
                - (@csize - @hnoteex_size) / 2 - @csize / 2)
            end
            page.draw_text(@font, @hnoteex_size, note.hnoteex, rt2ex)
          end
        end
        
        if note.lyrics and not note.lyrics.empty?
          note.lyrics.reverse.each_with_index do |l, i|
            rt3 = rt.add_xy(
              @lnote_size / 2 + (@lnote_size + 2) * i + 2,
              - (@csize - l.split(//).size * @lnote_size) / 2)
            page.draw_text(@font, @lnote_size, l, rt3)
          end
        end
      end
    end
  end

  def process_pagenum(params)
    @pages.each_with_index do |page, i|
      s = "( #{i + 1} / #{@pages.size} )"
      rt = Rectangle.new(
        (page.get_width - s.size * @pagenum_size / 2) / 2,
        @pagenum_margin, nil, nil)
      page.draw_text(@hfont, @pagenum_size, s, rt)
    end
  end

  def save(fname)
    @pdf.save_to_file(fname)
  end
end

class CommandParam
  def initialize(type, value)
    @type, @value = type, value
  end
  attr_accessor :type, :value
end

class NoteParam
  def initialize(note, noteex, hnote, hnoteex, lyrics)
    @note, @noteex, @hnote, @hnoteex, @lyrics = note, noteex, hnote, hnoteex, lyrics
  end
  attr_accessor :note, :noteex, :hnote, :hnoteex, :lyrics
end

def preview(fname)
  shex = Win32API.new('shell32.dll', 'ShellExecuteA', %w(p p p p p i), 'i')
  shex.call(0, 'open', fname, 0, 0, 1)
end

module DropFileViewerForm
  include VRVertLayoutManager
  include VRDropFileTarget
  
  def construct
    self.caption = 'kk4'
    self.move(100, 100, 300, 240)
    addControl(VRStatic, 'label0', '') # dummy
    addControl(VRStatic, 'label1', "テキストファイルを\nドロップしてください", WStyle::SS_CENTER)
    addControl(VRStatic, 'label2', '') # dummy
  end
  
  def self_dropfiles(files)
    files.each do |infname|
      process(infname)
    end
  end
end

def process(infname)
  outfname = infname.sub(/\.\w+/, '') + '.pdf'
  
  notes = []
  open(infname, 'r') do |infile|
    infile.readlines.each do |line|
      xs = line.split
      next if xs.empty?
      next if xs.first =~ /^#/
        if xs.first =~ /^\$/
          notes << CommandParam.new(*xs)
        else
          ys = xs.first.split(/[|｜]/)
          param = []
          ys.each do |zs|
            zs = zs.split(//)
            if zs[-1] =~ /^[丶┐]$/
              ex = zs[-1].gsub(/┐/, '┌')
              zs.pop
            else
              ex = nil
            end
            param << zs.map {|s| s.gsub('＃', '#') }
            param << ex
          end
          param += [nil, nil] if param.size < 3
          param << xs[1 .. -1]
          notes << NoteParam.new(*param)
        end
    end
  end
  
  score = Score.new
  score.process(notes)
  score.save(outfname)
  preview(outfname)
end


if $0 == __FILE__
  if ARGV.empty?
    VRLocalScreen.showForm(DropFileViewerForm)
    VRLocalScreen.messageloop
  else
    ARGV.each do |infname|
      process(infname)
    end
  end
end
