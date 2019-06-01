<cfcomponent name="amazonMWS" displayname="Amazon MWS">

<cfset this.accessKeyId = "">
<cfset this.secretAccessKey = "">
<cfset this.marketplaceID = "">
<cfset this.sellerID = "">
<cfset this.httpTimeOut = 120>
<cfset this.ordersVersion = "2011-01-01">
<cfset this.feedsVersion = "2009-01-01">
<cfset this.protocol = "https">
<cfset this.endPoint = "mws.amazonservices.com">
<cfset this.offSet = getTimeZoneInfo().utcTotalOffset>


<!---
	https://sellercentral.amazon.com/gp/mws/doc/en_US/bde/reports/v20090901/devGuide/index.html

--->

<cffunction name="init" access="public" returnType="amazonMWS" output="false"
		hint="Returns an instance of the CFC initialized.">
	
	<cfargument name="accessKeyId" type="string" required="true" hint="Amazon Access Key ID.">
	<cfargument name="secretAccessKey" type="string" required="true" hint="Amazon Secret Access Key.">
	<cfargument name="marketPlaceID" type="string" required="true" hint="Amazon Marketplace ID">
	<cfargument name="sellerID" type="string" required="true" hint="Amazon Seller ID">
	
	<cfargument name="endPoint" type="string" default="#this.endPoint#">
	
	<cfargument name="ordersVersion" type="string" default="#this.ordersVersion#" hint="Amazon Orders API Version">
	<cfargument name="feedsVersion" type="string" default="#this.feedsVersion#" hint="Amazon Feeds API Version">
	
	<cfargument name="userAgent" type="string" default="ColdFusion MWS CFC/0.1b (Language=ColdFusion)" hint="">
	<cfargument name="httpTimeOut" type="numeric" default="#this.httpTimeOut#">
	
	<cfset this.accessKeyId = arguments.accessKeyId>
	<cfset this.secretAccessKey = arguments.secretAccessKey>
	<cfset this.marketplaceID = arguments.marketplaceID>
	<cfset this.sellerID = arguments.sellerID>
	
	<cfset this.ordersVersion = arguments.ordersVersion>
	<cfset this.feedsVersion = arguments.feedsVersion>
	
	<cfset this.userAgent = arguments.userAgent>
	<cfset this.httpTimeOut = arguments.httpTimeOut>
	
	<cfset this.ordersPath = "/Orders/" & arguments.ordersVersion>
	
	<cfreturn this>
</cffunction>


<cffunction name="debugLog" output="false">
	<cfargument name="input" type="any" required="true">
	
	<cfif structKeyExists( request, "log" ) AND isCustomFunction( request.log )>
		<cfif isSimpleValue( arguments.input )>
			<cfset request.log( "AmazonMWS: " & arguments.input )>
		<cfelse>
			<cfset request.log( "AmazonMWS: (complex type)" )>
			<cfset request.log( arguments.input )>
		</cfif>
	<cfelse>
		<cftrace
			type="information"
			category="AmazonMWS"
			text="#( isSimpleValue( arguments.input ) ? arguments.input : "" )#"
			var="#arguments.input#"
		>
	</cfif>
	
	<cfreturn>
</cffunction>


<!--- ---------------------------------------------------------------------------------------------------------------------- --->
<!--- UTILTIES --->
<!--- ---------------------------------------------------------------------------------------------------------------------- --->

<cffunction name="ServiceStatus" access="public" output="false" returnType="struct">
	<cfset var params = { "Action" = "GetServiceStatus", "SellerId" = this.SellerID }>
	<cfset var response = invokeRequest( "https", "GET", this.ordersPath, this.ordersVersion, params )>
	
	<cfset response.status = "UNKNOWN">
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
		<cfset response.status = response.xml.GetServiceStatusResponse.GetServiceStatusResult.Status.XmlText>
	</cfif>
	
	<cfreturn response>
</cffunction>


<!--- ---------------------------------------------------------------------------------------------------------------------- --->
<!--- PRODUCT API --->
<!--- ---------------------------------------------------------------------------------------------------------------------- --->

<cffunction name="GetLowestOfferListingsForASIN" access="public" output="false" returnType="struct">
	<cfargument name="asin" type="string" required="true">
	<cfargument name="condition" type="string" default="New">

	<cfset var response = {}>
	<cfset var headers = {}>
	<cfset var params = buildParams(
		"Action" = "GetLowestOfferListingsForASIN"
	,	"MarketplaceId" = this.marketPlaceId
	,	"ASINList" = arguments.asin
	,	"ItemCondition" = arguments.condition
	,	"SellerId" = this.sellerID
	,	"Merchant" = this.sellerID
	)>
	
	<cfset response = invokeRequest( "https", "POST", "/Products/2011-10-01", "2011-10-01", params )>
	
	<cfreturn response>
</cffunction>


<!--- ---------------------------------------------------------------------------------------------------------------------- --->
<!--- FEEDS API --->
<!--- ---------------------------------------------------------------------------------------------------------------------- --->

<cffunction name="SubmitFeed" access="public" output="false" returnType="struct">
	<cfargument name="Type" type="string" required="true">
	<cfargument name="Content" type="string" required="true">
	<cfargument name="Purge" type="boolean" default="false">
	<cfargument name="ContentType" type="string" default="">
	
	<cfset var response = {}>
	<cfset var headers = {}>
	<cfset var params = buildParams(
		Action = "SubmitFeed"
	,	FeedType = arguments.type
	,	PurgeAndReplace = arguments.purge
	,	Merchant = this.sellerID
	)>
	
	<cfif NOT len( arguments.contentType ) AND left( arguments.Content, 5 ) IS "<?xml">
		<cfset headers = { "Content-Type" = "text/xml; charset=iso-8859-1" }>
	<cfelse>
		<cfset headers = { "Content-Type" = "text/tab-separated-values; charset=iso-8859-1" }>
	</cfif>
	
	<cfset response = invokeRequest( "https", "POST", "/", this.feedsVersion, params, {}, arguments.Content )>
	
	<cfreturn response>
</cffunction>


<cffunction name="GetFeedSubmissionList" access="public" output="false" returnType="struct">
	<cfargument name="FeedSubmissionIdList" type="string" required="false">
	<cfargument name="FeedTypeList" type="string" required="false">
	<cfargument name="FeedProcessingStatusList" type="string" required="false">
	<cfargument name="SubmittedFromDate" type="date" required="false">
	<cfargument name="SubmittedToDate" type="date" required="false">
	<cfargument name="Limit" type="numeric" default="10">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetFeedSubmissionList"
	,	Merchant = this.sellerID
	,	MaxCount = arguments.Limit
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="GetFeedSubmissionListByNextToken" access="public" output="false" returnType="struct">
	<cfargument name="NextToken" type="string" required="true">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetFeedSubmissionListByNextToken"
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>

	
<cffunction name="GetFeedSubmissionCount" access="public" output="false" returnType="struct">
	<cfargument name="FeedTypeList" type="string" required="false">
	<cfargument name="FeedProcessingStatusList" type="string" required="false">
	<cfargument name="SubmittedFromDate" type="date" required="false">
	<cfargument name="SubmittedToDate" type="date" required="false">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetFeedSubmissionCount"
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	<cfset response.count = -1>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
		<cfset response.status = response.xml.GetFeedSubmissionCountResponse.GetFeedSubmissionCountResult.Count.XmlText>
	</cfif>
	
	<cfreturn response>
</cffunction>

	
<cffunction name="GetFeedSubmissionResult" access="public" output="false" returnType="struct">
	<cfargument name="FeedId" type="string" required="true">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetFeedSubmissionResult"
	,	FeedSubmissionId = arguments.FeedId
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>

	
<cffunction name="RequestReport" access="public" output="false" returnType="struct">
	<cfargument name="ReportType" type="string" required="true">
	<cfargument name="StartDate" type="date" required="false">
	<cfargument name="EndDate" type="date" required="false">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "RequestReport"
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>

	
<cffunction name="GetReportRequestList" access="public" output="false" returnType="struct">
	<cfargument name="ReportRequestIdList" type="string" required="false">
	<cfargument name="ReportTypeList" type="string" required="false">
	<cfargument name="ReportProcessingStatusList" type="string" required="false">
	<cfargument name="RequestedFromDate" type="date" required="false">
	<cfargument name="RequestedToDate" type="date" required="false">
	<cfargument name="Limit" type="numeric" default="10">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetReportRequestList"
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>

	
<cffunction name="GetReportRequestListByNextToken" access="public" output="false" returnType="struct">
	<cfargument name="NextToken" type="string" required="true">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetReportRequestListByNextToken"
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="GetReportRequestCount" access="public" output="false" returnType="struct">
	<cfargument name="ReportTypeList" type="string" required="false">
	<cfargument name="ReportProcessingStatusList" type="string" required="false">
	<cfargument name="RequestedFromDate" type="string" required="false">
	<cfargument name="RequestedToDate" type="string" required="false">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetReportRequestCount"
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="GetReportList" access="public" output="false" returnType="struct">
	<cfargument name="ReportTypeList" type="string" required="false">
	<cfargument name="ReportRequestIdList" type="string" required="false">
	<cfargument name="Acknowledged" type="boolean" required="false">
	<cfargument name="RequestedFromDate" type="string" required="false">
	<cfargument name="RequestedToDate" type="string" required="false">
	<cfargument name="Limit" type="numeric" default="10">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetReportList"
	,	MaxCount = arguments.Limit
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="GetReportListByNextToken" access="public" output="false" returnType="struct">
	<cfargument name="NextToken" type="string" required="true">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetReportListByNextToken"
	,	MaxCount = arguments.Limit
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="GetReportCount" access="public" output="false" returnType="struct">
	<cfargument name="ReportTypeList" type="string" required="false">
	<cfargument name="Acknowledged" type="boolean" required="false">
	<cfargument name="AvailableFromDate" type="string" required="false">
	<cfargument name="AvailableToDate" type="string" required="false">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetReportCount"
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<cfset response = invokeRequest( "https", "GET", "/", this.feedsVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="GetReport" access="public" output="false" returnType="struct">
	<cfargument name="ReportId" type="string" required="true">
	<cfargument name="SaveFile" type="string" required="true">
	
	<cfset var response = {}>
	<cfset var params = buildParams(
		Action = "GetReport"
	,	Merchant = this.sellerID
	,	Marketplace = this.marketPlaceId
	,	argumentCollection = arguments
	)>
	
	<!--- <cfset response = invokeRequest( "http", "GET", "/", this.feedsVersion, params )> --->
	
	<cfset arguments.url = generateSignedURL( "https", "GET", this.endPoint, "/", this.feedsVersion, params )>
	
	<cfhttp
		result="response"
		method="GET"
		url="#arguments.url#"
		userAgent="#this.userAgent#"
		timeOut="#( this.httpTimeOut * 10 )#"
		charset="iso-8859-1"
		path="#getDirectoryFromPath( arguments.SaveFile )#"
		file="#getFileFromPath( arguments.SaveFile )#"
	/>
	
	<cfset response = duplicate( response )>
	<cfset response.success = false>
	
	<!--- RESPONSE CODE ERRORS --->
	<cfif isDefined( "response.responseHeader.Status_Code" )>
		<cfif response.responseHeader.Status_Code IS 503>
			<cfset response.errorDetail = "Error 503, submitting requests too quickly.">
		<cfelseif left( response.responseHeader.Status_Code, 1 ) IS 4>
			<cfset response.errorDetail = "Transient Error #response.responseHeader.Status_Code#, resubmit.">
		<cfelseif left( response.responseHeader.Status_Code, 1 ) IS 5>
			<cfset response.errorDetail = "Internal Amazon Error #response.responseHeader.Status_Code#">
		<cfelseif response.fileContent IS "Connection Timeout" OR response.fileContent IS "Connection Failure">
			<cfset response.errorDetail = response.fileContent>
		<cfelseif left( response.responseHeader.Status_Code, 1 ) IS 2>
			<cfset response.success = true>
		</cfif>
	</cfif>
	
	<cfreturn response>
</cffunction>


<!--- ---------------------------------------------------------------------------------------------------------------------- --->
<!--- ORDERS API --->
<!--- ---------------------------------------------------------------------------------------------------------------------- --->


<cffunction name="_listOrders" access="public" output="false" returnType="struct">
	<cfargument name="Token" type="string" required="false">
	<cfargument name="BuyerEmail" type="string" required="false">
	<cfargument name="SellerOrderID" type="string" required="false">
	<cfargument name="OrderStatus" type="string" required="false"><!--- Pending, Unshipped,PartiallyShipped, Shipped, Canceled, Unfulfillable --->
	<cfargument name="CreatedAfter" type="string" required="false">
	<cfargument name="CreatedBefore" type="string" required="false">
	<cfargument name="LastUpdatedAfter" type="string" required="false">
	<cfargument name="LastUpdatedBefore" type="string" required="false">
	<cfargument name="Marketplace" type="string" required="false">
	<cfargument name="Channel" type="string" required="false">
	<cfargument name="Limit" type="numeric" required="false">
	
	<cfset var response = {}>
	<cfset var params = { "Action" = "ListOrders" }>
	<cfset var x = 0>
	
	<cfif listFindNoCase( arguments.OrderStatus, "Unshipped" ) AND NOT listFindNoCase( arguments.OrderStatus, "PartiallyShipped" )>
		<cfset arguments.OrderStatus = listAppend( arguments.OrderStatus, "PartiallyShipped" )>
	<cfelseif listFindNoCase( arguments.OrderStatus, "PartiallyShipped" ) AND NOT listFindNoCase( arguments.OrderStatus, "Unshipped" )>
		<cfset arguments.OrderStatus = listAppend( arguments.OrderStatus, "Unshipped" )>
	</cfif>
	
	<!--- build request params --->
	<cfif structKeyExists( arguments, "Token" )>
		<cfset params[ "NextToken" ] = arguments.Token>
		<cfset params[ "Action" ] = "ListOrdersByNextToken">
	<cfelse>
		<cfif structKeyExists( arguments, "BuyerEmail" )>
			<cfset params[ "BuyerEmail" ] = arguments.BuyerEmail>
		</cfif>
		<cfif structKeyExists( arguments, "SellerOrderID" )>
			<cfset params[ "SellerOrderID" ] = arguments.SellerOrderID>
		</cfif>
		<cfif structKeyExists( arguments, "OrderStatus" )>
			<cfset this.expandParams( params, "OrderStatus", "Status", arguments.OrderStatus )>
		</cfif>
		<cfif structKeyExists( arguments, "CreatedAfter" )>
			<cfset params[ "CreatedAfter" ] = zDateFormat( arguments.CreatedAfter )>
			<cfif structKeyExists( arguments, "CreatedBefore" )>
				<cfset params[ "CreatedBefore" ] = zDateFormat( arguments.CreatedBefore )>
			</cfif>
		<cfelseif structKeyExists( arguments, "LastUpdatedAfter" )>
			<cfset params[ "LastUpdatedAfter" ] = zDateFormat( arguments.LastUpdatedAfter )>
			<cfif structKeyExists( arguments, "LastUpdatedBefore" )>
				<cfset params[ "LastUpdatedBefore" ] = zDateFormat( arguments.LastUpdatedBefore )>
			</cfif>
		</cfif>
		<cfif structKeyExists( arguments, "Marketplace" )>
			<cfset this.expandParams( params, "Marketplace", "Id", arguments.Marketplace )>
		</cfif>
		<cfif structKeyExists( arguments, "Channel" )>
			<cfset this.expandParams( params, "FulfillmentChannel", "Channel", arguments.Channel )>
		</cfif>
		<cfif structKeyExists( arguments, "Limit" )>
			<cfset params[ "MaxResultsPerPage" ] = arguments.Limit>
		</cfif>
	</cfif>
	
	<cfset response = invokeRequest( "https", "GET", this.ordersPath, this.ordersVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="ListOrders" access="public" output="false" returnType="struct">
	<cfargument name="OrderStatus" type="string" required="true"><!--- Pending, Unshipped,PartiallyShipped, Shipped, Canceled, Unfulfillable --->
	<cfargument name="CreatedAfter" type="date" required="false">
	<cfargument name="CreatedBefore" type="date" required="false">
	<cfargument name="LastUpdatedAfter" type="date" required="false">
	<cfargument name="LastUpdatedBefore" type="date" required="false">
	<cfargument name="Marketplace" type="string" default="#this.marketplaceID#">
	<cfargument name="Channel" type="string" default=""><!--- AFN,MFN --->
	<cfargument name="Limit" type="numeric" default="100">
	
	<cfreturn _listOrders( argumentCollection = arguments )>
</cffunction>


<cffunction name="ListOrdersByEmail" access="public" output="false" returnType="struct">
	<cfargument name="BuyerEmail" type="string" required="true">
	<cfargument name="CreatedAfter" type="date" required="false">
	<cfargument name="CreatedBefore" type="date" required="false">
	<cfargument name="Marketplace" type="string" default="#this.marketplaceID#">
	<cfargument name="Limit" type="numeric" default="100">
	
	<cfreturn _listOrders( argumentCollection = arguments )>
</cffunction>


<cffunction name="ListOrdersBySellerOrderID" access="public" output="false" returnType="struct">
	<cfargument name="SellerOrderID" type="string" required="true">
	<cfargument name="CreatedAfter" type="date" required="false">
	<cfargument name="CreatedBefore" type="date" required="false">
	<cfargument name="Marketplace" type="string" default="#this.marketplaceID#">
	<cfargument name="Limit" type="numeric" default="100">
	
	<cfreturn _listOrders( argumentCollection = arguments )>
</cffunction>


<cffunction name="ListOrdersByNextToken" access="public" output="false" returnType="struct">
	<cfargument name="Token" type="string" required="true">
	
	<cfreturn _listOrders( argumentCollection = arguments )>
</cffunction>


<cffunction name="GetOrder" access="public" output="false" returnType="struct">
	<cfargument name="OrderIDs" type="string" required="true">
	
	<cfset var response = {}>
	<cfset var params = { "Action" = "GetOrder", "SellerId" = this.SellerID }>
	
	<!--- build request params --->
	<cfset this.expandParams( params, "AmazonOrderId", "Id", arguments.OrderIDs )>
	
	<cfset response = invokeRequest( "https", "GET", this.ordersPath, this.ordersVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="ListOrderItems" access="public" output="false" returnType="struct">
	<cfargument name="OrderID" type="string" required="true">
	
	<cfset var params = { "Action" = "ListOrderItems", "AmazonOrderId" = arguments.OrderID, "SellerId" = this.SellerID }>
	<cfset var response = invokeRequest( "https", "GET", this.ordersPath, this.ordersVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="ListOrderItemsByNextToken" access="public" output="false" returnType="struct">
	<cfargument name="Token" type="string" required="true">
	
	<cfset var params = { "Action" = "ListOrderItemsByNextToken", "NextToken" = arguments.Token, "SellerId" = this.SellerID }>
	<cfset var response = invokeRequest( "https", "GET", this.ordersPath, this.ordersVersion, params )>
	
	<cfif response.success>
		<cfset response.xml = xmlParse( response.fileContent )>
	</cfif>
	
	<cfreturn response>
</cffunction>


<!--- ---------------------------------------------------------------------------------------------------------------------- --->
<!--- INTERNALS --->
<!--- ---------------------------------------------------------------------------------------------------------------------- --->


<cffunction name="HMAC_SHA256" returnType="binary" access="public" output="false"
	description="NSA SHA256 Algorithm">
	
	<cfargument name="signKey" type="string" required="true">
	<cfargument name="signMessage" type="string" required="true">

	<cfset var jMsg = JavaCast( "string", arguments.signMessage ).getBytes( "iso-8859-1" )>
	<cfset var jKey = JavaCast( "string", arguments.signKey ).getBytes( "iso-8859-1" )>
	<cfset var key = createObject( "java", "javax.crypto.spec.SecretKeySpec" )>
	<cfset var mac = createObject( "java", "javax.crypto.Mac" )>

	<cfset key = key.init( jKey, "HmacSHA256" )>
	<cfset mac = mac.getInstance( key.getAlgorithm() )>
	<cfset mac.init( key )>
	<cfset mac.update( jMsg )>

	<cfreturn mac.doFinal()>
</cffunction>


<cffunction name="buildParams" access="public" output="false" returnType="struct">
	<cfset var params = {}>
	<cfset var field = "">
	
	<cfloop index="field" list="Action,Merchant,Marketplace,Acknowledged,FeedType,PurgeAndReplace,ReportType,ReportId,FeedSubmissionId,NextToken">
		<cfif structKeyExists( arguments, field ) AND len( arguments[ field ] )>
			<cfset params[ field ] = arguments[ field ]>
		</cfif>
	</cfloop>
	
	<!--- <cfif structKeyExists( arguments, "Marketplace" )>
		<cfset this.expandParams( params, "Marketplace", "Id", arguments.Marketplace )>
	</cfif> --->
	<cfif structKeyExists( arguments, "FeedTypeList" ) AND len( arguments.FeedTypeList )>
		<cfset this.expandParams( params, "FeedTypeList", "Type", arguments.FeedTypeList )>
	</cfif>
	<cfif structKeyExists( arguments, "FeedProcessingStatusList" ) AND len( arguments.FeedProcessingStatusList )>
		<cfset this.expandParams( params, "FeedProcessingStatusList", "Status", arguments.FeedProcessingStatusList )>
	</cfif>
	<cfif structKeyExists( arguments, "ReportTypeList" ) AND len( arguments.ReportTypeList )>
		<cfset this.expandParams( params, "ReportTypeList", "Type", arguments.ReportTypeList )>
	</cfif>
	<cfif structKeyExists( arguments, "ReportRequestIdList" ) AND len( arguments.ReportRequestIdList )>
		<cfset this.expandParams( params, "ReportRequestIdList", "Id", arguments.ReportRequestIdList )>
	</cfif>
	<cfif structKeyExists( arguments, "ReportProcessingStatusList" ) AND len( arguments.ReportProcessingStatusList )>
		<cfset this.expandParams( params, "ReportProcessingStatusList", "Status", arguments.ReportProcessingStatusList )>
	</cfif>
	
	<cfloop index="field" list="StartDate,EndDate,AvailableFromDate,AvailableToDate,RequestedFromDate,RequestedToDate,SubmittedFromDate,SubmittedToDate">
		<cfif structKeyExists( arguments, field ) AND len( arguments[ field ] )>
			<cfset params[ field ] = zDateFormat( arguments[ field ] )>
		</cfif>
	</cfloop>
	
	<cfreturn params>
</cffunction>


<cffunction name="expandParams" access="public" output="false" returnType="struct">
	<cfargument name="params" type="struct" required="true">
	<cfargument name="field" type="string" required="true">
	<cfargument name="subfield" type="string" required="true">
	<cfargument name="value" type="string" required="true">
	
	<cfset var x = 0>
	
	<!--- <cfif listLen( arguments.value ) IS 1>
		<cfset arguments.params[ "#arguments.field#" ] = arguments.value>
	<cfelse> --->
		<cfloop index="x" from="1" to="#listLen( arguments.value )#">
			<cfset arguments.params[ "#arguments.field#.#arguments.subfield#.#x#" ] = listGetAt( arguments.value, x )>
		</cfloop>
	<!--- </cfif> --->
	
	<cfreturn arguments.params>
</cffunction>	


<cffunction name="zDateFormat" output="false" returnType="string">
    <cfargument name="date" type="date" required="true">
    
    <cfset arguments.date = dateAdd( "s", this.offSet, arguments.date )>
    <cfreturn dateFormat( arguments.date, "yyyy-mm-dd" ) & "T" & timeFormat( arguments.date, "HH:mm:ss") & "Z">
</cffunction>


<cffunction name="invokeRequest" access="public" output="false" returnType="struct">
    <cfargument name="protocol" type="string" required="true">
	<cfargument name="verb" type="string" required="true">
	<cfargument name="path" type="string" required="true">
	<cfargument name="version" type="string" required="true">
	<cfargument name="params" type="struct" default="#{}#">
	<cfargument name="headers" type="struct" default="#{}#">
	<cfargument name="body" type="string" default="">
	
	<cfset var item = "">
	<cfset var response = {
		success = false
	,	errorDetail = ""
	,	fileContent = ""
	}>
	
	<cfset arguments.url = generateSignedURL(
		arguments.protocol
	,	arguments.verb
	,	this.endPoint
	,	arguments.path
	,	arguments.version
	,	arguments.params
	)>
	
	<cfif request.debug AND request.dump>
		<cfset this.debugLog( arguments )>
	</cfif>
	
	<cfhttp
		result="response"
		method="#arguments.verb#"
		url="#arguments.url#"
		userAgent="#this.userAgent#"
		timeOut="#this.httpTimeOut#"
		charset="utf-8"
	>
		<cfloop item="item" collection="#arguments.headers#">
			<cfhttpparam type="header" name="#item#" value="#arguments.headers[ item ]#" encoded="false">
		</cfloop>
		<cfif len( arguments.body )>
			<cfhttpparam type="body" value="#arguments.headers[ item ]#">
		</cfif>
	</cfhttp>
	
	<cfset response = duplicate( response )>
	<cfset response.success = false>
	
	<!--- RESPONSE CODE ERRORS --->
	<cfif isDefined( "response.responseHeader.Status_Code" )>
		<cfif response.responseHeader.Status_Code IS 503>
			<cfset response.errorDetail = "Error 503, submitting requests too quickly.">
		<cfelseif left( response.responseHeader.Status_Code, 1 ) IS 4>
			<cfset response.errorDetail = "Transient Error #response.responseHeader.Status_Code#, resubmit.">
		<cfelseif left( response.responseHeader.Status_Code, 1 ) IS 5>
			<cfset response.errorDetail = "Internal Amazon Error #response.responseHeader.Status_Code#">
		<cfelseif response.fileContent IS "Connection Timeout" OR response.fileContent IS "Connection Failure">
			<cfset response.errorDetail = response.fileContent>
		<cfelseif left( response.responseHeader.Status_Code, 1 ) IS 2>
			<cfset response.success = true>
		</cfif>
	</cfif>
	
	<cfif NOT len( response.errorDetail ) AND find( "<Error>", response.fileContent )>
		<cfset response.errorDetail = "Response contains an error">
		<cfset response.xml = xmlParse( response.fileContent )>
		<cftry>
			<cfset response.errorDetail = response.xml.ErrorResponse.Error.Message.XmlText>
			<cfcatch></cfcatch>
		</cftry>
	</cfif>
	
	<cfif len( response.errorDetail )>
		<cftrace type="error" text="Amazon Shopping API Error">
	<cfelse>
		<cfset response.success = true>
	</cfif>
	
	<cfreturn response>
</cffunction>


<cffunction name="generateSignedURL" returnType="string" output="false">
	<cfargument name="protocol" type="string" default="http">
	<cfargument name="verb" type="string" default="GET">
	<cfargument name="endPoint" type="string" required="true">
	<cfargument name="requestURI" type="string" required="true">
	<cfargument name="version" type="string" required="true">
	<cfargument name="params" type="struct" default="#{}#">
	
	<cfset var key = "">
	
	<cfset arguments.block = "">
	<cfset arguments.cs = "">
	
	<cfset arguments.params[ "Version" ] = arguments.version>
	<cfif NOT structKeyExists( arguments.params, "Timestamp" )>
		<cfset arguments.params[ "Timestamp" ] = this.zDateFormat( now(), this.offSet )>
	</cfif>
	<cfset arguments.params[ "SignatureMethod" ] = "HmacSHA256">
	<cfset arguments.params[ "SignatureVersion"] = 2>
	
	<cfset arguments.block = uCase( arguments.verb )& chr(10)>
	<cfset arguments.block &= arguments.endPoint & chr(10)>
	<cfset arguments.block &= arguments.requestURI & chr(10)>
	
	<!--- Build arguments.canonical Query String --->
	<cfloop index="key" list="#listSort( structKeyList( arguments.params ), 'textNoCase', 'asc' )#">
		<cfset arguments.cs &= "&" & key & "=" & replaceList( urlEncodedFormat( arguments.params[ key ] ), "%2D,%5F", "-,_" )>
		<!--- <cfset arguments.cs &= "&" & key & "=" & urlEncodedFormat( replace( replace( replace( arguments.params[ key ], ",", "%2C", "all" ), ":", "%3A", "all" ), " ", "%20", "all" ) )> --->
	</cfloop>
	
	<!--- AWSAccessKeyId is not sorted --->
	<cfset arguments.params[ "AWSAccessKeyId" ] = this.accessKeyId>
	<cfset arguments.cs = "AWSAccessKeyId" & "=" & arguments.params[ "AWSAccessKeyId" ] & arguments.cs>
	<cfset arguments.block &= arguments.cs>
	<cfset arguments.params[ "Signature" ] = urlEncodedFormat( toBase64( HMAC_SHA256( this.secretAccessKey, arguments.block ) ) )>
	
	<cfset arguments.cs &= "&" & "Signature=" & arguments.params[ "Signature" ]>
	<cfset arguments.url = arguments.protocol & "://" & arguments.endPoint & arguments.requestURI & "?" & arguments.cs>
	
	<cfif request.debug AND request.dump>
		<cfset this.debugLog( arguments )>
	</cfif>
	
	<cfreturn arguments.url>
	
</cffunction>


</cfcomponent>