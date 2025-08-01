# Copyright 2025 Google LLC All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Multi-tenant tools for Google Analytics that accept tenant credentials."""

import base64
import json
import logging
from typing import Any, Dict, List

from google.oauth2 import service_account
from google.analytics import admin_v1beta, data_v1beta
from google.api_core.gapic_v1.client_info import ClientInfo

from analytics_mcp.coordinator import mcp
from analytics_mcp.tools.utils import (
    construct_property_rn,
    proto_to_dict,
    _get_package_version_with_fallback
)

logger = logging.getLogger(__name__)

# Read-only scope for Analytics
_READ_ONLY_ANALYTICS_SCOPE = "https://www.googleapis.com/auth/analytics.readonly"


def _create_client_info(tenant_id: str) -> ClientInfo:
    """Create client info with tenant ID for tracking."""
    return ClientInfo(
        user_agent=f"analytics-mcp/{_get_package_version_with_fallback()}/tenant-{tenant_id}"
    )


def _decode_credentials(tenant_credentials: str) -> service_account.Credentials:
    """Decode and validate tenant credentials."""
    try:
        # Decode base64
        cred_json = base64.b64decode(tenant_credentials).decode('utf-8')
        cred_data = json.loads(cred_json)
        
        # Create credentials object
        credentials = service_account.Credentials.from_service_account_info(
            cred_data,
            scopes=[_READ_ONLY_ANALYTICS_SCOPE]
        )
        return credentials
    except Exception as e:
        logger.error(f"Failed to decode credentials: {e}")
        raise ValueError("Invalid credentials format. Expected base64-encoded service account JSON")


@mcp.tool()
async def get_account_summaries_mt(
    tenant_id: str,
    tenant_credentials: str
) -> List[Dict[str, Any]]:
    """Retrieves information about the user's Google Analytics accounts and properties using tenant credentials.
    
    Args:
        tenant_id: Unique identifier for the tenant
        tenant_credentials: Base64-encoded service account JSON credentials
    """
    credentials = _decode_credentials(tenant_credentials)
    client = admin_v1beta.AnalyticsAdminServiceAsyncClient(
        credentials=credentials,
        client_info=_create_client_info(tenant_id)
    )
    
    summary_pager = await client.list_account_summaries()
    all_pages = [
        proto_to_dict(summary_page) async for summary_page in summary_pager
    ]
    return all_pages


@mcp.tool()
async def run_report_mt(
    tenant_id: str,
    tenant_credentials: str,
    property_id: int | str,
    date_ranges: List[Dict[str, str]],
    dimensions: List[str] = None,
    metrics: List[str] = None,
    dimension_filter: Dict[str, Any] = None,
    metric_filter: Dict[str, Any] = None,
    order_bys: List[Dict[str, Any]] = None,
    limit: int = None,
    offset: int = None
) -> Dict[str, Any]:
    """Runs a Google Analytics report using tenant-specific credentials.
    
    This multi-tenant version requires tenant credentials for data isolation.
    
    Args:
        tenant_id: Unique identifier for the tenant
        tenant_credentials: Base64-encoded service account JSON credentials
        property_id: The Google Analytics property ID
        date_ranges: List of date ranges for the report
        dimensions: List of dimensions to include
        metrics: List of metrics to include
        dimension_filter: Filter for dimensions
        metric_filter: Filter for metrics
        order_bys: Sorting configuration
        limit: Maximum number of rows to return
        offset: Number of rows to skip
    """
    credentials = _decode_credentials(tenant_credentials)
    client = data_v1beta.BetaAnalyticsDataAsyncClient(
        credentials=credentials,
        client_info=_create_client_info(tenant_id)
    )
    
    # Build the request
    request = data_v1beta.RunReportRequest(
        property=construct_property_rn(property_id),
        date_ranges=[data_v1beta.DateRange(**dr) for dr in date_ranges]
    )
    
    if dimensions:
        request.dimensions = [data_v1beta.Dimension(name=d) for d in dimensions]
    
    if metrics:
        request.metrics = [data_v1beta.Metric(name=m) for m in metrics]
    
    if dimension_filter:
        request.dimension_filter = data_v1beta.FilterExpression(**dimension_filter)
    
    if metric_filter:
        request.metric_filter = data_v1beta.FilterExpression(**metric_filter)
    
    if order_bys:
        request.order_bys = [data_v1beta.OrderBy(**ob) for ob in order_bys]
    
    if limit is not None:
        request.limit = limit
    
    if offset is not None:
        request.offset = offset
    
    # Execute the report
    response = await client.run_report(request)
    return proto_to_dict(response)


@mcp.tool()
async def run_realtime_report_mt(
    tenant_id: str,
    tenant_credentials: str,
    property_id: int | str,
    dimensions: List[str] = None,
    metrics: List[str] = None,
    dimension_filter: Dict[str, Any] = None,
    metric_filter: Dict[str, Any] = None,
    limit: int = None
) -> Dict[str, Any]:
    """Runs a Google Analytics realtime report using tenant-specific credentials.
    
    Args:
        tenant_id: Unique identifier for the tenant
        tenant_credentials: Base64-encoded service account JSON credentials
        property_id: The Google Analytics property ID
        dimensions: List of dimensions to include
        metrics: List of metrics to include
        dimension_filter: Filter for dimensions
        metric_filter: Filter for metrics
        limit: Maximum number of rows to return
    """
    credentials = _decode_credentials(tenant_credentials)
    client = data_v1beta.BetaAnalyticsDataAsyncClient(
        credentials=credentials,
        client_info=_create_client_info(tenant_id)
    )
    
    request = data_v1beta.RunRealtimeReportRequest(
        property=construct_property_rn(property_id)
    )
    
    if dimensions:
        request.dimensions = [data_v1beta.Dimension(name=d) for d in dimensions]
    
    if metrics:
        request.metrics = [data_v1beta.Metric(name=m) for m in metrics]
    
    if dimension_filter:
        request.dimension_filter = data_v1beta.FilterExpression(**dimension_filter)
    
    if metric_filter:
        request.metric_filter = data_v1beta.FilterExpression(**metric_filter)
    
    if limit is not None:
        request.limit = limit
    
    response = await client.run_realtime_report(request)
    return proto_to_dict(response)


@mcp.tool()
async def get_property_details_mt(
    tenant_id: str,
    tenant_credentials: str,
    property_id: int | str
) -> Dict[str, Any]:
    """Returns details about a property using tenant-specific credentials.
    
    Args:
        tenant_id: Unique identifier for the tenant
        tenant_credentials: Base64-encoded service account JSON credentials
        property_id: The Google Analytics property ID
    """
    credentials = _decode_credentials(tenant_credentials)
    client = admin_v1beta.AnalyticsAdminServiceAsyncClient(
        credentials=credentials,
        client_info=_create_client_info(tenant_id)
    )
    
    request = admin_v1beta.GetPropertyRequest(
        name=construct_property_rn(property_id)
    )
    response = await client.get_property(request=request)
    return proto_to_dict(response)