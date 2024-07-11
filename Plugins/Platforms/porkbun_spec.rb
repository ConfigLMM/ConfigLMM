
require_relative('../../lib/ConfigLMM/commands/refresh')
require_relative('../../lib/ConfigLMM/commands/deploy')
require 'porkbun'
require 'tty-logger'

RSpec.describe 'Porkbun' do

    let(:domains) {[
                     {
                         :domain => 'example.com'
                     },
                     {
                         :domain => 'example.org'
                     }
                  ]}

    let(:target) {
                     {
                         'Type' => 'PorkbunDNS',
                         'DNS'  => {
                                      'example.org' => { '@' => 'A=@me' }
                                   }
                     }
                 }

    it 'Refresh works' do
        state = instance_double('ConfigLMM::State')
        expect(ConfigLMM::State).to receive(:new).and_return(state)
        expect(state).to receive(:create!)
        expect(state).to receive(:item).twice.with('Porkbun').and_return({}) # Twice because we use it to validate result in test
        expect(state).to receive(:save)

        expect(::Porkbun).to receive(:ping).and_return({ :status => 'SUCCESS' })
        expect(::Porkbun::Domain).to receive(:list_all).and_return({ :status => 'SUCCESS', :domains => domains })
        expect(::Porkbun::DNS).to receive(:retrieve).with('example.com').and_return([{ :name => 'example.com' }])
        expect(::Porkbun::DNS).to receive(:retrieve).with('example.org').and_return([{ :name => 'example.org',
                                                                                       :content => 'example.com',
                                                                                       :type => 'ALIAS'
                                                                                     }])

        ENV['PORKBUN_API_KEY'] = 'whatever'
        ENV['PORKBUN_SECRET_API_KEY'] = 'whatever'
        ConfigLMM::Commands::Refresh.new('whatever.yaml', { :level => :info }).processConfig({'Porkbun' => target}, {})

        expect(state.item('Porkbun')).to include({
            'DNS' => {
                        'example.com' => {
                          :_meta_ => { :domain => 'example.com' },
                          :_records_=> [ { :name => 'example.com' } ]
                        },
                        'example.org' => {
                          :_meta_=> { :domain=>'example.org' },
                          :_records_=> [ {
                                             :content => 'example.com',
                                             :name => 'example.org',
                                             :type => 'ALIAS'
                                         }
                                       ]
                        }
                    },
            :Type => 'PorkbunDNS'
        })
    end

    it 'Deploy works' do
        state = instance_double('ConfigLMM::State')
        expect(ConfigLMM::State).to receive(:new).and_return(state)
        expect(state).to receive(:create!)
        expect(state).to receive(:item).twice.with('Porkbun').and_return({}) # Twice because we use it to validate result in test
        expect(state).to receive(:save)
        expect(HTTP).to receive(:get).and_return(HTTP::Response.new(body: '127.0.0.1',
                                                                    status: 200,
                                                                    :version => '1.1',
                                                                    request: nil))

        expect(::Porkbun).to receive(:ping).and_return({ :status => 'SUCCESS' })

        record = ::Porkbun::DNS.new({
                                      name: '',
                                      content: 'example.com',
                                      type: 'ALIAS',
                                      id: '12345',
                                      domain: 'example.org'
                                   })
        expect(::Porkbun::DNS).to receive(:retrieve).with('example.org').and_return([record])
        expect(::Porkbun::DNS).to receive(:create).with({
                                                           :content => "127.0.0.1",
                                                           :domain=>"example.org",
                                                           :name=>"",
                                                           :ttl=>600,
                                                           :type=>"A"
                                                       }).and_return(record)

        ENV['PORKBUN_API_KEY'] = 'whatever'
        ENV['PORKBUN_SECRET_API_KEY'] = 'whatever'
        ConfigLMM::Commands::Deploy.new('whatever.yaml', { :level => :info }).processConfig({'Porkbun' => target}, {})

        expect(state.item('Porkbun')['DNS']['example.org']).to include({ '@' => {
            :content=>"example.com",
            :domain => "example.org",
            :id => "12345",
            :name => "example.org",
            :prio => nil,
            :ttl => 600,
            :type => "ALIAS"
        }})
    end

end
