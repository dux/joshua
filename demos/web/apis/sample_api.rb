# Stress-tests every doc-relevant DSL piece: all typero param kinds,
# allow combos, named errors, class_detail, ref helpers.
class SampleApi < ApplicationApi
  documented
  class_desc   'Sample API exercising every typero kind'
  class_detail 'Use this namespace to verify every input renders in the explorer.'
  icon         'layers'

  desc 'Echoes every typero param kind so the form renderer is exercised'
  params do
    name         String,  required: true
    age          Integer, default: 30
    score        Float
    active       false
    role         String,  default: 'user', values: %w[user admin guest]
    email        :email
    homepage     :url
    bio?         String
  end
  def echo
    params.to_h
  end

  desc 'Trigger a named rescue (returns "Record not found")'
  def trigger_not_found
    error :not_found
  end

  desc 'Allows GET, POST, PUT, DELETE'
  allow :get, :post, :put, :delete
  def multi
    { method: @api.request&.request_method }
  end

  desc   'Sends a generated CSV via send_data'
  detail 'Demonstrates Joshua::BaseInstance#send_data (Rails / lux-fw style).'
  allow :get
  def report_csv
    csv = "id,text,done\n" + TodoApi::TODOS.map { |t| "#{t[:id]},#{t[:text]},#{t[:done]}" }.join("\n")
    send_data csv, name: 'todos.csv', content_type: 'text/csv'
  end

  desc   'Sends the gem favicon via send_file (inline preview)'
  detail 'Demonstrates send_file with download:false. Sets ETag + Last-Modified.'
  allow :get
  def favicon
    send_file File.expand_path('../../../../lib/misc/favicon.png', __dir__), download: false
  end
end
