require 'spec_helper'
require 'json'
require 'yaml'

describe 'cpi.json.erb' do
  let(:cpi_specification_file) { File.absolute_path(File.join(jobs_root, 'vcloud_cpi/spec')) }

  subject(:parsed_json) do
    context_hash = YAML.load_file(cpi_specification_file)
    context = TemplateEvaluationContext.new(context_hash, manifest)
    renderer = ERBRenderer.new(context)
    parsed_json = JSON.parse(renderer.render(cpi_json_erb))
    parsed_json
  end

  let(:jobs_root) { File.join(File.dirname(__FILE__), '../../../../../../../../', 'jobs') }
  let(:cpi_json_erb) { File.read(File.absolute_path(File.join(jobs_root, 'vcloud_cpi/templates/cpi.json.erb'))) }
  let(:manifest) do
    {
      'properties' => {
        'vcd' => {
          'url' => 'vcd-url',
          'user' => 'vcd-user',
          'password' => 'vcd-password',
          'entities' => {
              "organization" => 'vcd-entities-organization',
              "virtual_datacenter" => 'vcd-entities-virtual-datacenter',
              "vapp_catalog" => 'vcd-entities-vapp-catalog',
              "media_catalog" => 'vcd-entities-media-catalog',
              "media_storage_profile" => 'vcd-entities-media-storage-profile',
              "vapp_storage_profile" => 'vcd-entities-vapp-storage-profile',
              "vm_metadata_key" => 'vcd-entities-vm-metadata-key',
              "description" => 'vcd-entities-description'
          }
        },
        'blobstore' => {
          'address' => 'blobstore-address.example.com',
          'agent' => {
            'user' => 'agent-user',
            'password' => 'agent-password'
          }
        },
        'nats' => {
          'address' => 'nats-address.example.com',
          'password' => 'nats-password'
        }
      }
    }
  end

  it 'is able to render the erb given most basic manifest properties' do
    expect(subject).to eq({
      'cloud' => {
        'plugin' => 'vcloud',
        'properties' => {
          'agent' => {
            'blobstore' => {
              'options' => {
                'endpoint' => 'http://blobstore-address.example.com:25250',
                'password' => 'agent-password',
                'user' => 'agent-user'
              },
              'provider' => 'dav'
            },
            'mbus' => 'nats://nats:nats-password@nats-address.example.com:4222',
            'ntp' => [
              '0.pool.ntp.org',
              '1.pool.ntp.org'
            ]
          },
          'vcds' => [
            {
              'entities' => {
                'description' => 'vcd-entities-description',
                'media_catalog' => 'vcd-entities-media-catalog',
                'media_storage_profile' => 'vcd-entities-media-storage-profile',
                'organization' => 'vcd-entities-organization',
                'vapp_catalog' => 'vcd-entities-vapp-catalog',
                'vapp_storage_profile' => 'vcd-entities-vapp-storage-profile',
                'virtual_datacenter' => 'vcd-entities-virtual-datacenter',
                'vm_metadata_key' => 'vcd-entities-vm-metadata-key'
              },
              'password' => 'vcd-password',
              'url' => 'vcd-url',
              'user' => 'vcd-user'
            }
          ]
        }
      }
    })
  end

  context 'when using an s3 blobstore' do
    let(:rendered_blobstore) { subject['cloud']['properties']['agent']['blobstore'] }

    context 'when provided a minimal configuration' do
      before do
        manifest['properties']['blobstore'].merge!({
          'provider' => 's3',
          'bucket_name' => 'my_bucket',
          'access_key_id' => 'blobstore-access-key-id',
          'secret_access_key' => 'blobstore-secret-access-key',
        })
      end

      it 'renders the s3 provider section with the correct defaults' do
        expect(rendered_blobstore).to eq(
          {
            'provider' => 's3',
            'options' => {
              'bucket_name' => 'my_bucket',
              'access_key_id' => 'blobstore-access-key-id',
              'secret_access_key' => 'blobstore-secret-access-key',
              'use_ssl' => true,
              'port' => 443,
              's3_force_path_style' => false,
            }
          }
        )
      end
    end

    context 'when provided a maximal configuration' do
      before do
        manifest['properties']['blobstore'].merge!({
          'provider' => 's3',
          'bucket_name' => 'my_bucket',
          'access_key_id' => 'blobstore-access-key-id',
          'secret_access_key' => 'blobstore-secret-access-key',
          's3_region' => 'blobstore-region',
          'use_ssl' => false,
          's3_port' => 21,
          'host' => 'blobstore-host',
          's3_force_path_style' => true,
          'ssl_verify_peer' => true,
          's3_multipart_threshold' => 123,
          's3_signature_version' => '11'
        })
      end

      it 'renders the s3 provider section correctly' do
        expect(rendered_blobstore).to eq(
          {
            'provider' => 's3',
            'options' => {
              'bucket_name' => 'my_bucket',
              'access_key_id' => 'blobstore-access-key-id',
              'secret_access_key' => 'blobstore-secret-access-key',
              'region' => 'blobstore-region',
              'use_ssl' => false,
              'host' => 'blobstore-host',
              'port' => 21,
              's3_force_path_style' => true,
              'ssl_verify_peer' => true,
              's3_multipart_threshold' => 123,
              'signature_version' => '11',
            }
          }
        )
      end

      it 'prefers the agent properties when they are both included' do
        manifest['properties']['agent'] = {
          'blobstore' => {
            'access_key_id' => 'agent_access_key_id',
            'secret_access_key' => 'agent_secret_access_key',
            's3_region' => 'agent-region',
            'use_ssl' => true,
            's3_port' => 42,
            'host' => 'agent-host',
            's3_force_path_style' => true,
            'ssl_verify_peer' => true,
            's3_multipart_threshold' => 33,
            's3_signature_version' => '99',
          }
        }

        manifest['properties']['blobstore'].merge!({
          'access_key_id' => 'blobstore_access_key_id',
          'secret_access_key' => 'blobstore_secret_access_key',
          's3_region' => 'blobstore-region',
          'use_ssl' => false,
          's3_port' => 21,
          'host' => 'blobstore-host',
          's3_force_path_style' => false,
          'ssl_verify_peer' => false,
          's3_multipart_threshold' => 22,
          's3_signature_version' => '11',
        })

        expect(rendered_blobstore['options']['access_key_id']).to eq('agent_access_key_id')
        expect(rendered_blobstore['options']['secret_access_key']).to eq('agent_secret_access_key')
        expect(rendered_blobstore['options']['region']).to eq('agent-region')
        expect(rendered_blobstore['options']['use_ssl']).to be true
        expect(rendered_blobstore['options']['port']).to eq(42)
        expect(rendered_blobstore['options']['host']).to eq('agent-host')
        expect(rendered_blobstore['options']['s3_force_path_style']).to be true
        expect(rendered_blobstore['options']['ssl_verify_peer']).to be true
        expect(rendered_blobstore['options']['s3_multipart_threshold']).to eq(33)
        expect(rendered_blobstore['options']['signature_version']).to eq('99')
      end
    end
  end
end

class TemplateEvaluationContext
  attr_reader :name, :index
  attr_reader :properties, :raw_properties
  attr_reader :spec
  def initialize(spec, manifest)
    @name = spec['job']['name'] if spec['job'].is_a?(Hash)
    @index = spec['index']
    properties = {}
    spec['properties'].each do |name, x|
      default = x['default']
      copy_property(properties, manifest['properties'], name, default)
    end
    @properties = openstruct(properties)
    @raw_properties = properties
    @spec = openstruct(spec)
  end

  def recursive_merge(hash, other)
    hash.merge(other) do |_, old_value, new_value|
      if old_value.class == Hash && new_value.class == Hash
        recursive_merge(old_value, new_value)
      else
        new_value
      end
    end
  end

  def get_binding
    binding.taint
  end

  def p(*args)
    names = Array(args[0])
    names.each do |name|
      result = lookup_property(@raw_properties, name)
      return result unless result.nil?
    end
    return args[1] if args.length == 2
    raise UnknownProperty.new(names)
  end

  def if_p(*names)
    values = names.map do |name|
      value = lookup_property(@raw_properties, name)
      return ActiveElseBlock.new(self) if value.nil?
      value
    end
    yield *values
    InactiveElseBlock.new
  end

  private

  def copy_property(dst, src, name, default = nil)
    keys = name.split('.')
    src_ref = src
    dst_ref = dst
    keys.each do |key|
      src_ref = src_ref[key]
      break if src_ref.nil? # no property with this name is src
    end
    keys[0..-2].each do |key|
      dst_ref[key] ||= {}
      dst_ref = dst_ref[key]
    end
    dst_ref[keys[-1]] ||= {}
    dst_ref[keys[-1]] = src_ref.nil? ? default : src_ref
  end

  def openstruct(object)
    case object
      when Hash
        mapped = object.inject({}) { |h, (k,v)| h[k] = openstruct(v); h }
        OpenStruct.new(mapped)
      when Array
        object.map { |item| openstruct(item) }
      else
        object
    end
  end

  def lookup_property(collection, name)
    keys = name.split('.')
    ref = collection
    keys.each do |key|
      ref = ref[key]
      return nil if ref.nil?
    end
    ref
  end

  class UnknownProperty < StandardError
    def initialize(names)
      @names = names
      super("Can't find property '#{names.join("', or '")}'")
    end
  end

  class ActiveElseBlock
    def initialize(template)
      @context = template
    end
    def else
      yield
    end
    def else_if_p(*names, &block)
      @context.if_p(*names, &block)
    end
  end

  class InactiveElseBlock
    def else; end
    def else_if_p(*_)
      InactiveElseBlock.new
    end
  end
end

class ERBRenderer
  def initialize(context)
    @context = context
  end

  def render(erb_content)
    erb = ERB.new(erb_content)
    erb.result(@context.get_binding)
  end
end
