# -*- coding: utf-8 -*-

require "active_record"

class SRAID < ActiveRecord::Base
  def to_s
    "#{runid}, status => #{status}, paper => #{paper}"
  end
  
  scope :task, where( :status => "available" ).order("paper DESC, runid ASC")
  scope :paper_published, where( :status => "available", :paper => true )
  scope :paper_unpublished, where( :status => "available", :paper => false )
  scope :available, where( :status => "available" )
  scope :done, where( :status => "done" )
  scope :ongoing, where( :status => "ongoing" )
  scope :downloaded, where( :status => "downloaded" )
  scope :missing, where( :status => "missing" )
  scope :reported, where( :status => "reported" )
end
