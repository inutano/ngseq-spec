# -*- coding: utf-8 -*-
# updates sraid db
# status code
# available: 0

require "groonga"
require "yaml"
require "open-uri"
require "parallel"

def create_db(db_path)
  Groonga::Database.create(:path => db_path)
  
  Groonga::Schema.create_table("SRAIDs", :type => :hash)
  Groonga::Schema.change_table("SRAIDs") do |t|
    t.short_text("subid")
    t.short_text("studyid")
    t.short_text("expid")
    t.short_text("sampleid")
    t.uint16("status")
    t.bool("paper")
  end
  
  Groonga::Schema.create_table("Idx_hash", :type => :hash)
  Groonga::Schema.change_table("Idx_hash") do |t|
    t.index("SRAIDs.status")
    t.index("SRAIDs.paper")
  end
end

def add_record(insert)
  db = Groonga["SRAIDs"]
  runid = insert[:runid]
  db.add(runid)
  
  record = db[runid]
  record.subid = insert[:subid]
  record.studyid = insert[:studyid]
  record.expid = insert[:expid]
  record.sampleid = insert[:sampleid]
  record.status = insert[:status]
  record.paper = insert[:paper]
end

class Updater
  def load_files(config_path)
    config = YAML.load_file(config)
    fpath = config["fpath"]
    @resources = fpath["resources"]
    @accessions = fpath["sra_accessions"]
    @run_members = fpath["sra_run_members"]
    @publication = fpath["publication"]
    @publication_url = fpath["publication_url"]
    @ncbi_ftp = fpath["ncbi_ftp"]
    @now = Time.now.strftime("%Y%m%d%H%M%S")
  end
  
  def self.accessions
    FileUtils.mv(@accessions, File.join(@resources, "Acc.#{@now}")) if File.exist?(@accessions)
    `lftp -c "open #{@ncbi_ftp} && pget -n 8 SRA_Accessions.tab"`
  end
  
  def self.run_members
    FileUtils.mv(@run_members, File.join(@resources, "RMem.#{@now}")) if File.exist?(@run_members)
    `lftp -c "open #{@ncbi_ftp} && pget -n 8 SRA_Run_Members.tab"`
  end

  def self.publication
    FileUtils.mv(@publication, File.join(@resources, "pub.#{@now}")) if File.exist?(@publication)
    `wget -O #{@publication} #{publication_url}`
  end
  
  def self.all
    self.accessions
    self.run_members
    self.publication
  end

  def publication_parser
    pub_parsed = SRAsJSONParser.new(@publication)
    pub_parsed.all_subid
  end
end

def mess(message)
  puts Time.now.to_s + "\s" + message
end

if __FILE__ == $0
  config_path = File.expand_path(File.dirname(__FILE__)) + "/config.yaml"
  config = YAML.load_file(config_path)
  
  case ARGV.first
  when "--up"
    SRAIDsInit.migrate(:up)
  when "--down"
    SRAIDsInit.migrate(:down)
  when "--update"
    mess "connecting DB.."
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database => config["db_path"]
    )
    mess "done."
    
    if ARGV[1] != "--manual"
      mess "updating ID table files.."
      Updater.load_files(config_path)
      Updater.all
      mess "done."
    end
    
    mess "checking latest submissions.."
    mess "done."
    
    mess "insert submissions.."
    mess "done."
    
    mess ""
    mess
    
  when "--help"
  end
  
  puts "initializing updater.. #{Time.now}"
  updater = Update.new
  
  puts "checking newly submitted.. #{Time.now}"
  recorded = SRAID.all.map(&:runid)
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
  missed_runid = SRAID.missing.map(&:runid) + SRAID.reported.map(&:runid)
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
