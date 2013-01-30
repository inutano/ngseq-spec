# -*- coding: utf-8 -*-
# updates sraid db

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
  def self.load_files(config_path)
    config = YAML.load_file(config_path)
    fpath = config["fpath"]
    @@resources = fpath["resources"]
    @@ncbi_ftp = fpath["ncbi_ftp"]
    @@accessions = fpath["sra_accessions"]
    @@run_members = fpath["sra_run_members"]
    @@publication = fpath["publication"]
    @@publication_url = fpath["publication_url"]
    @@now = Time.now.strftime("%Y%m%d%H%M%S")
  end
  
  def self.accessions
    FileUtils.mv(@@accessions, File.join(@@resources, "Acc.#{@@now}")) if File.exist?(@@accessions)
    `lftp -c "open #{@@ncbi_ftp} && pget -n 8 SRA_Accessions.tab -o #{@@accessions}"`
  end
  
  def self.run_members
    FileUtils.mv(@@run_members, File.join(@@resources, "RMem.#{@@now}")) if File.exist?(@@run_members)
    `lftp -c "open #{@@ncbi_ftp} && pget -n 8 SRA_Run_Members.tab -o #{@@run_members}"`
  end

  def self.publication
    FileUtils.mv(@@publication, File.join(@@resources, "pub.#{@@now}")) if File.exist?(@@publication)
    `wget -O #{@@publication} #{@@publication_url}`
  end
  
  def self.all_files
    self.accessions
    self.run_members
    self.publication
  end
  
  def self.runids
    `grep '^.RR' #{@@accessions} | grep live | cut -f 1`.split("\n")
  end
end

class SRARun
  def self.load_files(config_path)
    config = YAML.load_file(config_path)
    fpath = config["fpath"]
    @@resources = fpath["resources"]
    @@result = fpath["result"]
    @@accessions = fpath["sra_accessions"]
    @@run_members = fpath["sra_run_members"]
    publication = fpath["publication"]
    @@published = open(publication){|f| JSON.load(f)}["ResultSet"]["Result"].map{|r| r["sra_id"] }.uniq
  end
  
  def initialize(runid)
    @runid = runid
  end
  
  def subid
    `grep -m 1 #{@runid} #{@@accessions} | cut -f 2`.chomp
  end
  
  def studyid
    `grep -m 1 #{@runid} #{@@run_members} | cut -f 5`.chomp
  end
  
  def expid
    `grep -m 1 #{@runid} #{@@run_members} | cut -f 3`.chomp
  end
  
  def sampleid
    `grep -m 1 #{@runid} #{@@run_members} | cut -f 4`.chomp
  end
  
  def status
    accessibility = `grep -m 1 #{@runid} #{@@accessions} | cut -f 9`.chomp
    result_path = File.join(@@result, @runid.slice(0..5), @runid)
    
    if accessibility == "controlled_access"
      #controlled
      2
    elsif !File.exist?(result_path)
      # available
      1
    elsif !Dir.entries(result_path).select{|f| f =~ /#{@runid}/ }.empty?
      # done
      6
    else
      # available
      1
    end
  end
  
  def paper
    @@published.include?(self.subid)
  end
  
  def insert
    { runid: @runid,
      subid: self.subid,
      studyid: self.studyid,
      expid: self.expid,
      sampleid: self.sampleid,
      status: self.status,
      paper: self.paper }
  end
end

def mess(message)
  puts Time.now.to_s + "\t" + message
end

if __FILE__ == $0
  config_path = File.join(File.expand_path(File.dirname(__FILE__)), "config.yaml")
  config = YAML.load_file(config_path)
  
  Groonga::Context.default_options = { encoding: :utf8 }
  
  case ARGV.first
  when "--up"
    create_db(config["db_path"])

  when "--update"
    mess "connecting DB.."
    Groonga::Database.open(config["db_path"])
    db = Groonga["SRAIDs"]
    mess "done."
    
    Updater.load_files(config_path)

    if ARGV[1] != "--manual"
      mess "updating ID table files.."
      
      Updater.all_files
      mess "done."
    end
    
    SRARun.load_files(config_path)
    
    mess "checking latest submissions.."
    latest_submissions = Updater.runids
    not_recorded = Parallel.map(latest_submissions) do |id|
      record = db[id]
      id if !record
    end
    recording_list = not_recorded.select{|id| id }
    mess "done."
    
    mess "making inserts.."
    begin
      inserts = Parallel.map(recording_list) do |id|
        SRARun.new(id).insert
      end
    rescue => e
      mess e.to_s
    end
    mess "done."
    
    mess "insert records into db.."
    Parallel.each(inserts) do |insert|
      add_record(insert)
    end
    mess "done."
    
    mess "db updated."
    mess "total number of records: " + db.size.to_s
    mess "available: " + db.select{|r| r.status == 1 }.size.to_s
    mess "controlled access: " + db.select{|r| r.status == 2 }.size.to_s
    mess "done: " + db.select{|r| r.status == 6 }.size.to_s
    
    mess "paper published: " + db.select{|r| r.paper == true }.size.to_s
    
  when "--help"
    text = <<EOS
db_update.rb ver. 0.1 2013.01.16

synopsis
  ruby db_update.rb <option>
  
opetions
  --up
    create groonga db, table and schema.
    
  --update
    update accessions and run_members table file, publication list.
    add new records into db.
    
  --update --manual
    does not update table files, just calculate ids not inserted and put them into db.
    
  --help
    you are watching me.
EOS
    puts text
  
  when "--debug"
    #require "ap"
    Groonga::Database.open(config["db_path"])
    db = Groonga["SRAIDs"]
    ap db.map{|r| [r.key, r.subid, r.status, r.paper, ] }[0..10]
    
    ap db.select{|r| r.status == 1 }.map{|r| r.key.key }[0..10]
    
    puts "total number of records: " + db.size.to_s
    puts "available: " + db.select{|r| r.status == 1 }.size.to_s
    puts "done: " + db.select{|r| r.status == 3 }.size.to_s
    puts "controlled access: " + db.select{|r| r.status == 2 }.size.to_s
  end
end
