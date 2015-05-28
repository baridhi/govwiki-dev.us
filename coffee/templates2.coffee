
###
# file: templates2.coffee ----------------------------------------------------------------------
#
# Class to manage templates and render data on html page.
#
# The main method : render(data), get_html(data)
#-------------------------------------------------------------------------------------------------
###



# LOAD FIELD NAMES 
fieldNames = {}


render_field_value =(n,data) ->
  v=data[n]
  if not data[n]
    return ''

  if n == "web_site"
    return "<a target='_blank' href='#{v}'>#{v}</a>"
  else
    return v
  
  

render_field_name = (fName) ->
  if fieldNames[fName]?
    return fieldNames[fName]

  s = fName.replace(/_/g," ")
  s = s.charAt(0).toUpperCase() + s.substring(1)
  return s


render_field = (fName,data)->
  if "_" == substr fName, 0, 1
    """
    <div>
        <span class='f-nam'>#{render_field_name fName}</span>
        <span class='f-val'>&nbsp;</span>
    </div>
    """
  else
    return '' unless fValue = data[fName]
    """
    <div>
        <span class='f-nam'>#{render_field_name fName}</span>
        <span class='f-val'>#{render_field_value(fName,data)}</span>
    </div>
    """

  
render_fields = (fields,data,template)->
  h = ''
  for field,i in fields
    fValue = render_field_value field, data
    if ('' != fValue)
      fName = render_field_name field
      h += template(name: fName, value: fValue)
  return h


under = (s) -> s.replace(/[\s\+\-]/g, '_')


render_tabs = (initial_layout, data, tabset, parent) ->
  #layout = add_other_tab_to_layout initial_layout, data
  layout = initial_layout
  templates = parent.templates
  plot_handles = {}

  layout_data =
    title: data.gov_name,
    tabs: [],
    tabcontent: ''
  
  for tab,i in layout
    layout_data.tabs.push
      tabid: under(tab.name),
      tabname: tab.name,
      active: (if i>0 then '' else 'active')

  for tab,i in layout
    detail_data =
      tabid: under(tab.name),
      tabname: tab.name,
      active: (if i>0 then '' else 'active')
      tabcontent: ''
    switch tab.name
      when 'Overview + Elected Officials'
        detail_data.tabcontent += render_fields tab.fields, data, templates['tabdetail-namevalue-template']
        for official,i in data.elected_officials.record
          official_data =
            title: if '' != official.title then "Title: " + official.title else ''
            name: if '' != official.full_name then "Name: " + official.full_name else ''
            email: if '' != official.email_address then "Email: " + official.email_address else ''
            termexpires: if '' != official.term_expires then "Term Expires: " + official.term_expires else ''
          official_data.image = '<img src="'+official.photo_url+'" alt="" />' if '' != official.photo_url
          detail_data.tabcontent += templates['tabdetail-official-template'](official_data)
      when 'Employee Compensation'
        h = ''
        h += render_fields tab.fields, data, templates['tabdetail-namevalue-template']
        detail_data.tabcontent += templates['tabdetail-employee-comp-template'](content: h)
        tabset.bind tab.name, (tpl_name, data) ->
          options =
            xaxis:
              minTickSize: 1
              labelWidth: 100
            yaxis:
              tickFormatter: (val, axis) ->
                return ''
            series:
              bars:
                show: true
                barWidth: .4
                align: "center"
          if not plot_handles['median-comp-graph']
            options.xaxis.ticks = [[1, "Median Total Gov. Comp"], [2, "Median Total Individual Comp"]]
            plot_spec = []
            plot_data_bottom = [[1, data['median_total_comp_per_ft_emp'] / data['median_total_comp_over_median_individual_comp']], [2, data['median_total_comp_per_ft_emp']]]
            plot_data_top = [[], []]
            plot_spec.push
              data: plot_data_bottom
            ###
            plot_spec.push
              data: plot_data_top
            ###
            plot_handles['median-comp-graph'] = $("#median-comp-graph").plot(plot_spec, options)
          if not plot_handles['median-pension-graph']
            options.xaxis.ticks = [[1, "Median Pension for Retiree w/ 30 Years"], [2, "Median Total Individual Comp"]]
            plot_spec = []
            plot_data_bottom = [[1, data['median_pension_30_year_retiree']], [2, data['median_earnings']]]
            plot_data_top = [[], []]
            plot_spec.push
              data: plot_data_bottom
            ###
            plot_spec.push
              data: plot_data_top
            ###
            plot_handles['median-pension-graph'] = $("#median-pension-graph").plot(plot_spec, options)
          #if not plot_handles['pct-pension-graph']
          if false
            plot_spec = []
            plot_data_bottom = [[], []]
            plot_data_top = [[], []]
            plot_spec.push
              data: plot_data_bottom
              label: "Pension & OPEB (req'd) as % of total revenue"
            ###
            plot_spec.push
              data: plot_data_top
              label: "Median Total Individual Comp"
            ###
            plot_handles['pct-pension-graph'] = $("#pct-pension-graph").plot(plot_spec, options)
      when 'Financial Health'
        h = ''
        h += render_fields tab.fields, data, templates['tabdetail-namevalue-template']
        detail_data.tabcontent += templates['tabdetail-financial-health-template'](content: h)
        tabset.bind tab.name, (tpl_name, data) ->
          options =
            series:
              pie:
                show: true
          if not plot_handles['public-safety-pie']
            plot_spec = [{label: 'Public safety expense', data: data['public_safety_exp_over_tot_gov_fund_revenue']}, {label: 'Other gov. fund revenue', data: 100 - data['public_safety_exp_over_tot_gov_fund_revenue']}]
            plot_handles['public-safety-pie'] = $("#public-safety-pie").plot(plot_spec, options)
      else
        detail_data.tabcontent += render_fields tab.fields, data, templates['tabdetail-namevalue-template']
    
    layout_data.tabcontent += templates['tabdetail-template'](detail_data)
  return templates['tabpanel-template'](layout_data)


get_layout_fields = (la) ->
  f = {}
  for t in la
    for field in t.fields
      f[field] = 1
  return f

get_record_fields = (r) ->
  f = {}
  for field_name of r
    f[field_name] = 1
  return f

get_unmentioned_fields = (la, r) ->
  layout_fields = get_layout_fields la
  record_fields = get_record_fields r
  unmentioned_fields = []
  unmentioned_fields.push(f) for f of record_fields when not layout_fields[f]
  return unmentioned_fields


add_other_tab_to_layout = (layout=[], data) ->
  #clone the layout
  l = $.extend true, [], layout
  t =
    name: "Other"
    fields: get_unmentioned_fields l, data

  l.push t
  return l


# converts tab template described in google fusion table to 
# tab template
convert_fusion_template=(templ) ->
  tab_hash={}
  tabs=[]
  # returns hash of field names and their positions in array of field names
  get_col_hash = (columns) ->
    col_hash ={}
    col_hash[col_name]=i for col_name,i in templ.columns
    return col_hash
  
  # returns field value by its name, array of fields, and hash of fields
  val = (field_name, fields, col_hash) ->
    fields[col_hash[field_name]]
  
  # converts hash to an array template
  hash_to_array =(hash) ->
    a = []
    for k of hash
      tab = {}
      tab.name=k
      tab.fields=hash[k]
      a.push tab
    return a

    
  col_hash = get_col_hash(templ.col_hash)
  placeholder_count = 0
  
  for row,i in templ.rows
    category = val 'general_category', row, col_hash
    #tab_hash[category]=[] unless tab_hash[category]
    fieldname = val 'field_name', row, col_hash
    if not fieldname then fieldname = "_" + String ++placeholder_count
    fieldNames[val 'field_name', row, col_hash]=val 'description', row, col_hash
    if category
      tab_hash[category]?=[]
      tab_hash[category].push n: val('n', row, col_hash), name: fieldname

  categories = Object.keys(tab_hash)
  for category in categories
    fields = []
    for obj in tab_hash[category]
      fields.push obj
    fields.sort (a,b) ->
      return a.n - b.n
    newFields = []
    for field in fields
      newFields.push field.name
    tab_hash[category] = newFields

  tabs = hash_to_array(tab_hash)
  return tabs


class Templates2

  @list = undefined
  @templates = undefined
  @data = undefined
  @events = undefined

  constructor:() ->
    @list = []
    @events = {}
    templateList = ['tabpanel-template', 'tabdetail-template', 'tabdetail-namevalue-template', 'tabdetail-official-template', 'tabdetail-employee-comp-template', 'tabdetail-financial-health-template']
    templatePartials = ['tab-template']
    @templates = {}
    for template,i in templateList
      @templates[template] = Handlebars.compile($('#' + template).html())
    for template,i in templatePartials
      Handlebars.registerPartial(template, $('#' + template).html())

  add_template: (layout_name, layout_json) ->
    @list.push
      parent:this
      name:layout_name
      render:(dat) ->
        @parent.data = dat
        render_tabs(layout_json, dat, this, @parent)
      bind: (tpl_name, callback) ->
        if not @parent.events[tpl_name]
          @parent.events[tpl_name] = [callback]
        else
          @parent.events[tpl_name].push callback
      activate: (tpl_name) ->
        if @parent.events[tpl_name]
          for e,i in @parent.events[tpl_name]
            e tpl_name, @parent.data

  load_template:(template_name, url) ->
    $.ajax
      url: url
      dataType: 'json'
      cache: true
      success: (template_json) =>
        @add_template(template_name, template_json)
        return

  load_fusion_template:(template_name, url) ->
    $.ajax
      url: url
      dataType: 'json'
      cache: true
      success: (template_json) =>
        t = convert_fusion_template template_json
        @add_template(template_name, t)
        return


  get_names: ->
    (t.name for t in @list)

  get_index_by_name: (name) ->
    for t,i in @list
      if t.name is name
        return i
     return -1

  get_html: (ind, data) ->
    if (ind is -1) then return  ""
    
    if @list[ind]
      return @list[ind].render(data)
    else
      return ""

  activate: (ind, tpl_name) ->
    if @list[ind]
      @list[ind].activate tpl_name

module.exports = Templates2
