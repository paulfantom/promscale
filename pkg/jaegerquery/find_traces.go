// This file and its contents are licensed under the Apache License 2.0.
// Please see the included NOTICE for copyright information and
// LICENSE for a copy of the license.

package jaegerquery

import (
	"context"
	"fmt"

	"github.com/jaegertracing/jaeger/model"
	"github.com/jaegertracing/jaeger/storage/spanstore"
	jaegertranslator "github.com/open-telemetry/opentelemetry-collector-contrib/pkg/translator/jaeger"
	"github.com/timescale/promscale/pkg/pgxconn"
	"go.opentelemetry.io/collector/model/pdata"
)

func findTraces(ctx context.Context, conn pgxconn.PgxConn, q *spanstore.TraceQueryParameters) ([]*model.Trace, error) {
	query, params := findTracesQuery(q)
	fmt.Println(query, params)
	rows, err := conn.Query(ctx, query, params...)
	if err != nil {
		return nil, fmt.Errorf("querying traces: %w", err)
	}
	defer rows.Close()

	traces := pdata.NewTraces()
	for rows.Next() {
		if rows.Err() != nil {
			return nil, fmt.Errorf("trace row iterator: %w", rows.Err())
		}
		ScanRow(rows, &traces)

	}
	if rows.Err() != nil {
		return nil, fmt.Errorf("trace row iterator: %w", rows.Err())
	}

	batch, err := jaegertranslator.InternalTracesToJaegerProto(traces)
	if err != nil {
		return nil, fmt.Errorf("internal-traces-to-jaeger-proto: %w", err)
	}

	return batchSliceToTraceSlice(batch), nil
}

func batchSliceToTraceSlice(bSlice []*model.Batch) []*model.Trace {
	// Mostly Copied from Jaeger's grpc_client.go
	// https://github.com/jaegertracing/jaeger/blob/067dff713ab635ade66315bbd05518d7b28f40c6/plugin/storage/grpc/shared/grpc_client.go#L179
	traces := make([]*model.Trace, 0)
	var traceID model.TraceID
	var trace *model.Trace
	for j := range bSlice {
		batch := bSlice[j]
		for i := range batch.Spans {
			span := batch.Spans[i]
			if span.TraceID != traceID {
				trace = &model.Trace{}
				traceID = span.TraceID
				traces = append(traces, trace)
			}
			//copy over the process from the batch
			span.Process = batch.Process
			trace.Spans = append(trace.Spans, span)
		}
	}
	return traces
}
