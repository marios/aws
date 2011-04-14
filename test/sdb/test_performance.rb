require File.dirname(__FILE__) + '/test_helper.rb'
require File.dirname(__FILE__) + '/../test_credentials.rb'
require 'simple_performer'
require 'eventmachine'
require 'faraday'
require_relative 'faraday_em_adapter'


class TestPerformance < Test::Unit::TestCase

  def setup
    TestCredentials.get_credentials
    STDOUT.sync = true
    @domain = 'sdb_speed_test_domain'
    @item = 'toys'
    @attr = {'Jon' => %w{beer car}}
    # Interface instance
    @sdb = Aws::SdbInterface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key)
    @sdb_em = Aws::SdbInterface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key, :connection_mode=>:eventmachine)
  end

  def test_puts


    x = 50

#    assert @sdb_em.create_domain(@domain), 'create_domain fail'

    ret = nil
    SimplePerformer.puts_duration("non em puts") do
      ret = put_bunch(@sdb, x)
    end
    x.times do |i|
      assert ret[i][:request_id].length > 10
    end
    SimplePerformer.puts_duration("em puts") do
      EventMachine.run do

        ret = put_bunch(@sdb_em, x)

#      unless wait_for_connections_and_stop
#        Still some connections running, schedule a check later
        EventMachine.add_periodic_timer(1) {
#          wait_for_connections_and_stop
          puts 'ret.size = ' + ret.size.to_s
          if ret.size >= 50
            puts 'stopping loop'
            EventMachine.stop
          end
        }
#      end
      end
    end

    x.times do |i|
      assert ret[i][:request_id].length > 10
    end

  end

  def test_selects
#    SimplePerformer.puts_duration("non em selects") do
#      sel = "select * from `#{@domain}`"
#      ret = @sdb.select(sel)
#      p ret
#    end

    SimplePerformer.puts_duration("non em selects") do
      EventMachine.run do
        sel = "select * from `#{@domain}`"
        ret = @sdb_em.select(sel)
        p ret
      end
    end

    # get attributes
#    values = @sdb_em.get_attributes(@domain, @item)[:attributes]['Jon'].to_a.sort
    # compare to original list
#    assert_equal values, @attr['Jon'].sort
  end

  def wait_for_connections_and_stop
    if @connections.empty?
      EventMachine.stop
      true
    else
      puts "Waiting for #{@connections.size} connection(s) to finish ..."
      false
    end
  end

  def put_bunch(sdb, x)
    ret = []
    x.times do |i|
      r = sdb.put_attributes(@domain, "#{@item}_#{i}", @attr)
      if r.respond_to?(:async?)
        p r
        r.on_success do |response|
          puts "#{i} response = " + response.inspect
          ret << response
        end
      else
        ret << r
      end
    end
    ret
  end


end