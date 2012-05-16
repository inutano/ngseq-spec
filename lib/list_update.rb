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
  scope :available, where( :status => "available" )
  scope :done, where( :status => "done" )
  scope :controlled, where( :status => "controlled" )
  scope :missing, where( :status => "missing" )
  scope :reported, where( :status => "reported" )
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
  puts "number of recorded items: #{recorded.length}"
  
  list_parsed = updater.get_accessions.map{|l| l.split("\t") }
  live_on_ftp = list_parsed.select do |line|
    id = line[0]
    status = line[2]
    id =~ /^.RR/ && status == "live"
  end
  newly_submitted = live_on_ftp.delete_if do |line|
    runid = line.first
    recorded.include?(runid)
  end
  puts "number of newly submitted: #{newly_submitted.length}"
  
  puts "inserting new records.. #{Time.now}"
  SRAID.transaction do
    begin
      newly_submitted.each do |line|
        insert = { paper: false,
                   runid: line[0],
                   subid: line[1],
                   studyid: line[12],
                   expid: line[10],
                   sampleid: line[11],
                   status: "available"
                 }
        SRAID.create(insert)
      end
    rescue ActiveRecord::StatementInvalid
      puts "STATEMENT INVALID: trying again.."
      retry
    end
  end
  puts "done."
  
  puts "checking status changed items.. #{Time.now}"
  missed_runid = SRAID.missing.map(&runid) + SRAID.reported.map(&runid)
  if not missed_runid.empty?
    live_runid_on_ftp = live_on_ftp.map{|l| l.first }
    status_changed_runid = missed_runid.select do |runid|
      live_runid_on_ftp.include?(runid)
    end
  else
    status_changed_runid = []
  end
  puts "number of status changed: #{status_changed_runid.length}"
  
  puts "updating.."
  SRAID.transaction do
    begin
      status_changed_runid.each do |runid|
        record = SRAID.find_by_runid(runid)
        record.status = "available"
        record.save
      end
    rescue ActiveRecord::StatementInvalid
      puts "STATEMENT INVALID: trying again.."
      retry
    end
  end
  puts "done."
  
  puts "checking items under the controlled access.. #{Time.now}"
  controlled_access = live_on_ftp.select{|l| l[8] == "controlled_access" }
  puts "number of controlled access: #{controlled_access.length}"
  
  puts "updating.. #{Time.now}"
  SRAID.transaction do
    begin
      controlled_access.each do |line|
        runid = line.first
        record = SRAID.find_by_runid(runid)
        if not record.status == "controlled"
          record.status = "controlled"
          record.save
        end
      end
    rescue ActiveRecord::StatementInvalid
      puts "STATEMENT INVALID: trying again.."
      retry
    end
  end
  puts "done."
  
  
  puts "checking data which has published article.. #{Time.now}"
  paperpublished_subid = updater.get_paperpublished_subid
  puts "number of paper-published items (submission id) #{paperpublished_subid.length}"
  
  puts "updating.. #{Time.now}"
  SRAID.transaction do
    begin
      paperpublished_subid.each do |subid|
        record = SRAID.find_by_subid(subid)
        if record && record.paper != true
          record.paper = true
          record.save
        end
      end
    rescue ActiveRecord::StatementInvalid
      puts "STATEMENT INVALID: trying again.."
      retry
    end
  end
  puts "done."
  
  puts "DB is up-to-date. #{Time.now}"
  num_a = SRAID.available.length
  num_d = SRAID.done.length
  num_c = SRAID.controlled.length
  puts "available: #{num_a}, done: #{num_d}, controlled: #{num_c}"
end
