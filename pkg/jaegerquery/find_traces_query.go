// This file and its contents are licensed under the Apache License 2.0.
// Please see the included NOTICE for copyright information and
// LICENSE for a copy of the license.

package jaegerquery

import (
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgtype"
	"github.com/jaegertracing/jaeger/storage/spanstore"
	"github.com/timescale/promscale/pkg/pgmodel/ingestor"
	"github.com/timescale/promscale/pkg/pgxconn"
	"go.opentelemetry.io/collector/model/pdata"
)

const (
	fullTraceSQLFormat = `
	SELECT
		s.trace_id,
	   	s.span_id,
       		s.parent_span_id,
       		s.start_time start_times,
       		s.end_time end_times,
       		s.span_kind,
       		s.dropped_tags_count 			dropped_tags_counts,
       		s.dropped_events_count 			dropped_events_counts,
       		s.dropped_link_count 			dropped_link_counts,
       		s.trace_state 				trace_states,
       		s_url.url 				schema_urls,
       		sn.name     				span_names,
	   	ps_trace.jsonb(s.resource_tags) 	resource_tags,
	   	ps_trace.jsonb(s.span_tags) 		span_tags,
	   	array_agg(e.name) FILTER(WHERE e IS NOT NULL)			event_names,
       		array_agg(e.time) FILTER(WHERE e IS NOT NULL)			event_times,
	   	array_agg(e.dropped_tags_count) FILTER(WHERE e IS NOT NULL)	event_dropped_tags_count,
	   	jsonb_agg(ps_trace.jsonb(e.tags)) FILTER(WHERE e IS NOT NULL)	event_tags,
	   	inst_lib.name 				library_name,
	   	inst_lib.version 			library_version,
		inst_lib_url.url 			library_schema_url,
		array_agg(lk.linked_trace_id) FILTER(WHERE lk IS NOT NULL)	links_linked_trace_ids,
		array_agg(lk.linked_span_id)  FILTER(WHERE lk IS NOT NULL)	links_linked_span_ids,
		array_agg(lk.trace_state)     FILTER(WHERE lk IS NOT NULL)	links_trace_states,
		array_agg(lk.dropped_tags_count) FILTER(WHERE lk IS NOT NULL) 	links_dropped_tags_count,
		jsonb_agg(lk.tags) FILTER(WHERE lk IS NOT NULL)			links_tags
	FROM
		_ps_trace.span s
	INNER JOIN
		_ps_trace.span_name sn ON s.name_id = sn.id
	LEFT JOIN
		_ps_trace.schema_url s_url ON s.resource_schema_url_id = s_url.id
	LEFT JOIN
		_ps_trace.event e ON e.span_id = s.span_id AND e.trace_id = s.trace_id
	LEFT JOIN
		_ps_trace.instrumentation_lib inst_lib ON s.instrumentation_lib_id = inst_lib.id
	LEFT JOIN
		_ps_trace.schema_url inst_lib_url ON inst_lib_url.id = inst_lib.schema_url_id
	LEFT JOIN
		_ps_trace.link lk ON lk.trace_id = s.trace_id AND lk.span_id = s.span_id
	WHERE
	  %s
	GROUP BY
	  s.trace_id,
	  s.span_id,
	  s.parent_span_id,
	  s.start_time,
	  s.end_time,
	  s.resource_tags,
	  s.span_tags,
	  sn.name,
	  s_url.url,
	  inst_lib.name,
	  inst_lib.version,
	  inst_lib_url.url
	ORDER BY s.trace_id --todo: get rid of for lookup by trace_id`

	subqueryFormat = `
	SELECT
		DISTINCT trace_id
	FROM _ps_trace.span s
	WHERE
		%s
	`
)

func findTracesQuery(q *spanstore.TraceQueryParameters) (string, []interface{}) {
	subquey, params := buildTraceIDSubquery(q)
	whereClause := fmt.Sprintf("s.trace_id IN (%s)", subquey)
	return fmt.Sprintf(
		fullTraceSQLFormat,
		whereClause), params
}

func buildTraceIDSubquery(q *spanstore.TraceQueryParameters) (string, []interface{}) {
	quals := make([]string, 0, 15)
	params := make([]interface{}, 0, 15)

	if len(q.ServiceName) > 0 {
		params = append(params, q.ServiceName)
		qual := fmt.Sprintf(`s.resource_tags OPERATOR(ps_trace.?) ('service.name' OPERATOR(ps_trace.==) $%d)`, len(params))
		quals = append(quals, qual)
	}
	if len(q.OperationName) > 0 {
		params = append(params, q.OperationName)
		qual := fmt.Sprintf(`s.name_id =
		(
			SELECT
				id
			FROM
				_ps_trace.span_name sn
			WHERE
				name = $%d
		)`, len(params))
		quals = append(quals, qual)
	}
	if len(q.Tags) > 0 {
		for k, v := range q.Tags {
			params = append(params, k, v)
			qual := fmt.Sprintf(`s.span_tags OPERATOR(ps_trace.?) ($%d OPERATOR(ps_trace.==) $%d)`, len(params)-1, len(params))
			quals = append(quals, qual)
		}
	}

	//todo check the inclusive semantics here
	var defaultTime time.Time
	if q.StartTimeMin != defaultTime {
		params = append(params, q.StartTimeMin)
		quals = append(quals, fmt.Sprintf(`s.start_time >= $%d`, len(params)))
	}
	if q.StartTimeMax != defaultTime {
		params = append(params, q.StartTimeMax)
		quals = append(quals, fmt.Sprintf(`s.start_time <= $%d`, len(params)))
	}

	var defaultDuration time.Duration
	if q.DurationMin != defaultDuration {
		params = append(params, q.DurationMin)
		quals = append(quals, fmt.Sprintf(`(s.end_time - s.start_time) >= $%d`, len(params)))
	}
	if q.DurationMax != defaultDuration {
		params = append(params, q.DurationMax)
		quals = append(quals, fmt.Sprintf(`(s.end_time - s.start_time) <= $%d`, len(params)))
	}

	query := ""
	if len(quals) > 0 {
		query = fmt.Sprintf(subqueryFormat, strings.Join(quals, " AND "))
	} else {
		query = fmt.Sprintf(subqueryFormat, "TRUE")
	}

	if q.NumTraces != 0 {
		query += fmt.Sprintf(" LIMIT %d", q.NumTraces)
	}
	return query, params
}

type spanDBResult struct {
	traceId             pgtype.UUID
	spanId              int64
	parentSpanId        pgtype.Int8
	startTime           time.Time
	endTime             time.Time
	kind                pgtype.Text
	droppedTagsCounts   int
	droppedEventsCounts int
	droppedLinkCounts   int
	traceState          pgtype.Text
	schemaUrl           pgtype.Text
	spanName            string
	resourceTags        map[string]interface{}
	spanTags            map[string]interface{}

	// From events table.
	// for events, the entire slice can be nil but not any element within the slice
	eventNames            *[]string
	eventTimes            *[]time.Time
	eventDroppedTagsCount *[]int
	eventTags             *[]map[string]interface{}

	// From instrumentation lib table.
	instLibName      *string
	instLibVersion   *string
	instLibSchemaUrl *string

	// From link table.
	linksLinkedTraceIds   pgtype.UUIDArray
	linksLinkedSpanIds    *[]int64
	linksTraceStates      *[]*string
	linksDroppedTagsCount *[]int
	linksTags             *[]map[string]interface{}
}

func ScanRow(row pgxconn.PgxRows, traces *pdata.Traces) error {
	dbRes := spanDBResult{}

	if err := row.Scan(
		// Span table.
		&dbRes.traceId,
		&dbRes.spanId,
		&dbRes.parentSpanId,
		&dbRes.startTime,
		&dbRes.endTime,
		&dbRes.kind,
		&dbRes.droppedTagsCounts,
		&dbRes.droppedEventsCounts,
		&dbRes.droppedLinkCounts,
		&dbRes.traceState,
		&dbRes.schemaUrl,
		&dbRes.spanName,
		&dbRes.resourceTags,
		&dbRes.spanTags,

		// Event table.
		&dbRes.eventNames, // 14
		&dbRes.eventTimes,
		&dbRes.eventDroppedTagsCount,
		&dbRes.eventTags,

		// Instrumentation lib table.
		&dbRes.instLibName,
		&dbRes.instLibVersion,
		&dbRes.instLibSchemaUrl,

		// Link table.
		&dbRes.linksLinkedTraceIds,
		&dbRes.linksLinkedSpanIds,
		&dbRes.linksTraceStates,
		&dbRes.linksDroppedTagsCount,
		&dbRes.linksTags,
	); err != nil {
		return fmt.Errorf("scanning traces: %w", err)
	}

	span := traces.ResourceSpans().AppendEmpty()
	if err := populateSpan(span, &dbRes); err != nil {
		return fmt.Errorf("populate span error: %w", err)
	}

	return nil
}

func populateSpan(
	// From span table.
	resourceSpan pdata.ResourceSpans,
	dbResult *spanDBResult) error {

	resourceSpan.Resource().Attributes().InitFromMap(makeAttributes(dbResult.resourceTags))

	instrumentationLibSpan := resourceSpan.InstrumentationLibrarySpans().AppendEmpty()
	if dbResult.instLibSchemaUrl != nil {
		instrumentationLibSpan.SetSchemaUrl(*dbResult.instLibSchemaUrl)
	}

	instLib := instrumentationLibSpan.InstrumentationLibrary()
	if dbResult.instLibName != nil {
		instLib.SetName(*dbResult.instLibName)
	}
	if dbResult.instLibVersion != nil {
		instLib.SetVersion(*dbResult.instLibVersion)
	}

	// Populating a span.
	ref := instrumentationLibSpan.Spans().AppendEmpty()

	// Type preprocessing.
	traceId, err := makeTraceId(dbResult.traceId)
	if err != nil {
		return fmt.Errorf("makeTraceId: %w", err)
	}
	ref.SetTraceID(traceId)

	id := makeSpanId(&dbResult.spanId)
	ref.SetSpanID(id)

	// We use a pointer since parent id can be nil. If we use normal int64, we can get parsing errors.
	var temp *int64
	if err := dbResult.parentSpanId.AssignTo(&temp); err != nil {
		return fmt.Errorf("assigning parent span id: %w", err)
	}
	parentId := makeSpanId(temp)
	ref.SetParentSpanID(parentId)

	if dbResult.traceState.Status == pgtype.Present {
		ref.SetTraceState(pdata.TraceState(dbResult.traceState.String))
	}

	if dbResult.schemaUrl.Status == pgtype.Present {
		resourceSpan.SetSchemaUrl(dbResult.schemaUrl.String)
	}

	ref.SetName(dbResult.spanName)

	if dbResult.kind.Status == pgtype.Present {
		ref.SetKind(makeKind(dbResult.kind.String))
	}

	ref.SetStartTimestamp(pdata.NewTimestampFromTime(dbResult.startTime))
	ref.SetEndTimestamp(pdata.NewTimestampFromTime(dbResult.endTime))

	ref.SetDroppedAttributesCount(uint32(dbResult.droppedTagsCounts))
	ref.SetDroppedEventsCount(uint32(dbResult.droppedEventsCounts))
	ref.SetDroppedLinksCount(uint32(dbResult.droppedLinkCounts))

	ref.Attributes().InitFromMap(makeAttributes(dbResult.spanTags))

	if dbResult.eventNames != nil {
		populateEvents(ref.Events(), dbResult)
	}
	if dbResult.linksLinkedSpanIds != nil {
		if err := populateLinks(ref.Links(), dbResult); err != nil {
			return fmt.Errorf("populate links error: %w", err)
		}
	}
	return nil
}

func populateEvents(
	spanEventSlice pdata.SpanEventSlice,
	dbResult *spanDBResult) {

	n := len(*dbResult.eventNames)
	for i := 0; i < n; i++ {
		event := spanEventSlice.AppendEmpty()
		event.SetName((*dbResult.eventNames)[i])
		event.SetTimestamp(pdata.NewTimestampFromTime((*dbResult.eventTimes)[i]))
		event.SetDroppedAttributesCount(uint32((*dbResult.eventDroppedTagsCount)[i]))
		event.Attributes().InitFromMap(makeAttributes((*dbResult.eventTags)[i]))
	}
}

func populateLinks(
	spanEventSlice pdata.SpanLinkSlice,
	dbResult *spanDBResult) error {

	n := len(*dbResult.linksLinkedSpanIds)

	var linkedTraceIds [][16]byte
	if err := dbResult.linksLinkedTraceIds.AssignTo(&linkedTraceIds); err != nil {
		return fmt.Errorf("linksLinkedTraceIds: AssignTo: %w", err)
	}

	for i := 0; i < n; i++ {
		link := spanEventSlice.AppendEmpty()

		link.SetTraceID(pdata.NewTraceID(linkedTraceIds[i]))

		spanId := makeSpanId(&(*dbResult.linksLinkedSpanIds)[i])
		link.SetSpanID(spanId)

		if (*dbResult.linksTraceStates)[i] != nil {
			traceState := *((*dbResult.linksTraceStates)[i])
			link.SetTraceState(pdata.TraceState(traceState))
		}
		link.SetDroppedAttributesCount(uint32((*dbResult.linksDroppedTagsCount)[i]))
		link.Attributes().InitFromMap(makeAttributes((*dbResult.linksTags)[i]))
	}
	return nil
}

// makeAttributes makes attribute map using tags.
func makeAttributes(tags map[string]interface{}) map[string]pdata.AttributeValue {
	m := make(map[string]pdata.AttributeValue, len(tags))
	// todo: attribute val as array?
	for k, v := range tags {
		switch val := v.(type) {
		case int64:
			m[k] = pdata.NewAttributeValueInt(val)
		case bool:
			m[k] = pdata.NewAttributeValueBool(val)
		case string:
			m[k] = pdata.NewAttributeValueString(val)
		case float64:
			m[k] = pdata.NewAttributeValueDouble(val)
		case []byte:
			m[k] = pdata.NewAttributeValueBytes(val)
		default:
			panic(fmt.Sprintf("unknown tag type %T", v))
		}
	}
	return m
}

func makeTraceId(s pgtype.UUID) (pdata.TraceID, error) {
	var bSlice [16]byte
	if err := s.AssignTo(&bSlice); err != nil {
		return pdata.TraceID{}, fmt.Errorf("trace id assign to: %w", err)
	}
	return pdata.NewTraceID(bSlice), nil
}

func makeSpanId(s *int64) pdata.SpanID {
	if s == nil {
		// Send an empty Span ID.
		return pdata.NewSpanID([8]byte{})
	}

	b8 := ingestor.Int64ToByteArray(*s)
	return pdata.NewSpanID(b8)
}

func makeKind(s string) pdata.SpanKind {
	switch s {
	case "SPAN_KIND_CLIENT":
		return pdata.SpanKindClient
	case "SPAN_KIND_SERVER":
		return pdata.SpanKindServer
	case "SPAN_KIND_INTERNAL":
		return pdata.SpanKindInternal
	case "SPAN_KIND_CONSUMER":
		return pdata.SpanKindConsumer
	case "SPAN_KIND_PRODUCER":
		return pdata.SpanKindProducer
	case "SPAN_KIND_UNSPECIFIED":
		return pdata.SpanKindUnspecified
	default:
		panic(fmt.Sprintf("unknown span kind: %s", s))
	}
}
