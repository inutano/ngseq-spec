# -*- coding: utf-8 -*-

require "#{File.expand_path(File.dirname(__FILE__))}/parse_sras_json.rb"
require "fileutils"
require "active_record"

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => "./production.sqlite3"
)

class SRAIDsInit < ActiveRecord::Migration
  def self.up
    create_table(:sraids) do |t|
      t.string :runid, :null => false
      t.string :subid, :null => false
      t.string :studyid, :null => false
      t.string :expid, :null => false
      t.string :sampleid, :null => false
      t.string :status, :null => false # done, ongoing, available, missing, downloaded, controlled
      t.boolean :paper, :null => false # paper published or not
      t.timestamps
    end
  end
  def self.down
  end
end

class SRAID < ActiveRecord::Base
  def to_s
    "#{runid}, status => #{status}, paper => #{paper}"
  end
  
  scope :missing, where( :status => "missing" )
end

class Update
  def initialize
    @current_dir = "#{File.expand_path(File.dirname(__FILE__))}"
    @accessions = "#{@current_dir}/SRA_Accessions.tab"
    @run_members = "#{@current_dir}/SRA_Run_Members.tab"
    @publication = "#{@current_dir}/publication.json"
    
    now = "#{Time.now.strftime("%m%d%H%M%S")}"
    prev_dir = "#{@current_dir}/previous"
    if File.exist?(@accessions)
      FileUtils.mv(@accessions, "#{prev_dir}/SRA_Accessions_#{now}.tab")
    end
    if File.exist?(@run_members)
      FileUtils.mv(@run_members, "#{prev_dir}/SRA_Run_Members_#{now}.tab")
    end
    if File.exist?(@publication)
      FileUtils.mv(@publication, "#{prev_dir}/publication_#{now}.tab")
    end
    
    @ncbi_ftp = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
  end
  
  def get_accessions
    `lftp -c "open #{@ncbi_ftp} && pget -n 8 SRA_Accessions.tab"`
    open(@accessions).readlines
  end
  
  def get_run_members
    `lftp -c "open #{@ncbi_ftp} && pget -n 8 SRA_Run_Members.tab"`
    open(@run_members).readlines
  end

  def get_paperpublished_subid
    publication_url =  "http://sra.dbcls.jp/cgi-bin/publication2.php"
    `wget -O #{@publication} #{publication_url}`
    pub_parsed = SRAsJSONParser.new(@publication)
    pub_parsed.all_subid
  end
end

if __FILE__ == $0
  if !File.exist?("./production.sqlite3")
    puts "begin DB migration #{Time.now}"
    SRAIDsInit.migrate(:up)
  end
  
  puts "initializing updater.. #{Time.now}"
  updater = Update.new
  
  puts "checking newly submitted.. #{Time.now}"
  recorded = SRAID.all.map(&runid)
  newly_submitted = updater.get_accessions.select do |line|
    line_sp = line.split("\t")
    status = line_sp[2]
    runid = line_sp.first
    line =~ /^.RR/ && status == "live" && !recorded.include?(runid)
  end
  
  puts "inserting new records.. #{Time.now}"
  SRAID.transaction do
    begin
      newly_submitted.each do |line|
        col = line.split("\t")
        insert = { paper: false,
                   runid: col[0],
                   subid: col[1],
                   studyid: col[12],
                   expid: col[10],
                   sampleid: col[11],
                   status: "available"
                 }
        SRAID.create(insert)
        puts "#{insert[:runid]} inserted as an available data."
      end
    rescue ActiveRecord::StatementInvalid
      puts "STATEMENT INVALID: trying again.."
      retry
    end
  end
  
  puts "checking if status of recorded data changed.. #{Time.now}"
  missing_data = SRAID.missing
  available_run_ids = available_run.map{|l| l.split("\t").first }
  SRAID.transaction do
    begin
      missing_data.each do |record|
        runid = record.runid
        if availble_run_ids.include?(runid)
          record.status = "available"
          record.save
        end
      end
    rescue ActiveRecord::StatementInvalid
      puts "STATEMENT INVALID: trying again.."
      retry
    end
  end

  puts "checking data under the controlled access.. #{Time.now}"
  controlled_run = available_run.select{|l| l.split("\t")[8] == "controlled_access" }
  
  puts "updating.. #{Time.now}"
  SRAID.transaction do
    begin
      controlled_run.each do |line|
        runid = line.split("\t").first
        record = SRAID.find_by_runid(runid)
        record.status = "controlled"
        record.save
        puts "updated #{record.to_s}"
      end
    rescue ActiveRecord::StatementInvalid
      puts "STATEMENT INVALID: trying again.."
      retry
    end
  end
  
  puts "checking data which has published article.. #{Time.now}"
  paperpublished_subid = updater.get_paperpublished_subid
  
  puts "updating.. #{Time.now}"
  SRAID.transaction do
    begin
      paperpublished_subid.each do |subid|
        record = SRAID.find_by_subid(subid)
        if record
          record.paper = true
          record.save
        end
      end
    rescue ActiveRecord::StatementInvalid
      puts "STATEMENT INVALID: trying again.."
      retry
    end
  end
end
