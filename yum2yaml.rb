#!/usr/bin/env ruby

# frozen_string_literal: true

require 'parseconfig'
require 'yaml'
require 'yaml/sort'

yum_dir = './spec/fixtures/almalinux/9'

VALID_YUMREPO_KEYS = %w[
  name
  target
  descr
  mirrorlist
  baseurl
  enabled
  gpgcheck
  payload_gpgcheck
  repo_gpgcheck
  gpgkey
  mirrorlist_expire
  include
  exclude
  gpgcakey
  includepkgs
  enablegroups
  module_hostfiles
  failovermethod
  keepalive
  retriers
  http_caching
  timeout
  metadata_expire
  protect
  priority
  minrate
  throttle
  bandwidth
  cost
  proxy
  proxy_username
  proxy_password
  s3_enabled
  sslcacert
  sslverify
  sslclientkey
  metalink
  skip_if_unavaiable
  assumeyes
  deltarpm_percentage
  deltarpm_metadata_percentage
  username
  passwword
].freeze

def str2bool(str)
  case str
  when Regexp.new('true', 'i'), '1'
    true
  else
    false
  end
end

# mangle keys:
# name -> descr
# enabled -> convert value to boolean
# gpgcheck -> convert value to boolean
# metadata_expire -> convert value to integer
def mangle_keys(conf)
  conf['descr'] = conf['name']
  conf.delete('name')

  %w[
    enabled
    gpgcheck
  ].each do |k|
    conf[k] = str2bool(conf[k])
  end

  conf['metadata_expire'] = conf['metadata_expire'].to_i
  conf
end

# remove all keys that are not a valid yumrepo_core param/prop
#
# specific keys known to be unsupported by yumrepo_core:
# enabled_metadata=0
# countme=1
#
# https://github.com/puppetlabs/puppetlabs-yumrepo_core/blob/main/lib/puppet/type/yumrepo.rb
def rm_keys(conf)
  conf.slice(*VALID_YUMREPO_KEYS)
end

def conf2yumrepo(conf, target)
  # add target: '/etc/yum.repos.d/almalinux-plus.repo'
  conf['target'] = target
  conf = mangle_keys(conf)
  rm_keys(conf)
end

doc = {
  'yum::os_default_repos' => [],
  'yum::repos' => {},
}

Dir.foreach(yum_dir) do |f|
  next if f =~ %r{^\.}

  config = ParseConfig.new(File.join(yum_dir, f))
  target = File.join('/etc/yum.repos.d', f)
  doc['yum::os_default_repos'] += config.groups
  config.params.each do |repo_name, repo_conf|
    doc['yum::repos'][repo_name] = conf2yumrepo(repo_conf, target)
  end
end

raw_yaml = YAML.dump(doc)
sorted_yaml = Yaml::Sort::Parser.new.parse(raw_yaml).sort
puts "---\n#{sorted_yaml}\n"
