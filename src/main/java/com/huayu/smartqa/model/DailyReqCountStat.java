package com.huayu.smartqa.model;

import java.time.LocalDate;

public record DailyReqCountStat(
        LocalDate recordDate,
        Long totalRequestCount
) {
}