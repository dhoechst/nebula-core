/**
 * @author aidan@nebulaconsulting.co.uk
 * @date 09/11/2018
 */
global inherited sharing class TestRecordSource {

    private static final String GENERATOR_SOBJECT_FIELD = Test_Record_Generator__mdt.SObject__c.getDescribe().getName();
    private static final String GENERATOR_VARIANT_FIELD = Test_Record_Generator__mdt.Variant__c.getDescribe().getName();

    private List<Test_Record_Generator__mdt> mockMetadata;
    private List<Test_Record_Generator_Field__mdt> mockFieldMetadata;

    private SObjectIndex generatorMetadata {get {
        if(generatorMetadata == null) {
            generatorMetadata = new SObjectIndex(
                    new List<String>{ GENERATOR_SOBJECT_FIELD, GENERATOR_VARIANT_FIELD})
                    .putAll((mockMetadata != null) ? mockMetadata :
                            [
                                    SELECT Apex_Class__c, Priority__c, SObject__c, Variant__c, Parameters__c
                                    FROM Test_Record_Generator__mdt
                                    ORDER BY Priority__c DESC
                            ]);
        }
        return generatorMetadata;
    } set;}

    private SObjectIndex generatorFieldMetadata {get {
        if(generatorFieldMetadata == null) {
            generatorFieldMetadata = new SObjectIndex(
                    Test_Record_Generator_Field__mdt.Test_Record_Generator__c.getDescribe().getName())
                    .putAll((mockFieldMetadata != null) ? mockFieldMetadata :
                            [
                                    SELECT Test_Record_Generator__c, Field__c, Value__c, Apex_Class__c,
                                            Apex_Class_Parameters__c
                                    FROM Test_Record_Generator_Field__mdt
                            ]);
        }
        return generatorFieldMetadata;
    } set;}

    private Map<Id, TestRecordGenerator> generators;

    global TestRecordSource() {
        generators = new Map<Id, TestRecordGenerator>();
    }

    public TestRecordSource(List<Test_Record_Generator__mdt> mockMetadata) {
        this();
        this.mockMetadata = mockMetadata;
    }

    private TestRecordGenerator getGenerator(SObjectType objectType, String variant) {
        Test_Record_Generator__mdt thisGeneratorMetadata = (Test_Record_Generator__mdt) generatorMetadata.get(
                new Map<String, Object>{
                        GENERATOR_SOBJECT_FIELD => objectType.getDescribe().getName(),
                        GENERATOR_VARIANT_FIELD => variant
                });
        if(thisGeneratorMetadata == null) {
            throw new ClassNotFoundException(
                    'No Test_Record_Generator__mdt found for '
                            + objectType.getDescribe().getName()
                            + (variant != null ? ', variant: ' + variant : ''));
        } else {
            return getGenerator(thisGeneratorMetadata);
        }
    }

    private TestRecordGenerator getGenerator(Test_Record_Generator__mdt thisGeneratorMetadata) {
        TestRecordGenerator returnGenerator = generators.get(thisGeneratorMetadata.Id);
        if(returnGenerator == null) {
            returnGenerator = createGenerator(thisGeneratorMetadata);
        }
        return returnGenerator;
    }

    private TestRecordGenerator createGenerator(Test_Record_Generator__mdt thisGeneratorMetadata) {
        Type generatorType = TypeLoader.getType(thisGeneratorMetadata.Apex_Class__c);
        if (generatorType == null) {
            throw new ClassNotFoundException('No matching class found for ' + thisGeneratorMetadata.Apex_Class__c +
                    '. Check that it is global and that the namespace is included.');
        } else {
            TestRecordGenerator newGenerator = (TestRecordGenerator)TypeLoader.getInstance(generatorType, thisGeneratorMetadata.Parameters__c);
            newGenerator.setup(this, thisGeneratorMetadata, generatorFieldMetadata.getAll(thisGeneratorMetadata.Id));
            generators.put(thisGeneratorMetadata.Id, newGenerator);
            return newGenerator;
        }
    }

    private SObject getObjectWithoutInsert(SObjectType objectType, String variant, Map<String, Object> params) {
        return getGenerator(objectType, variant).getObjectNoInsert(params);
    }

    private SObject getObjectWithInsert(SObjectType objectType, String variant, Map<String, Object> params) {
        return getGenerator(objectType, variant).getObjectWithInsert(params);
    }

    global Builder getObject(SObjectType sObjectType) {
        return new Builder(this, sObjectType);
    }

    global class Builder {
        private TestRecordSource parent;
        private SObjectType sObjectType;
        private String variant;
        private Map<String, Object> parameters;

        private Builder(TestRecordSource parent, SObjectType sObjectType) {
            this.parent = parent;
            this.sObjectType = sObjectType;
        }

        global Builder asVariant(String variant) {
            this.variant = variant;
            return this;
        }

        global Builder useParameters(Map<String, Object> parameters) {
            this.parameters = parameters;
            return this;
        }

        global SObject withInsert() {
            return parent.getObjectWithInsert(sObjectType, variant, parameters);
        }

        global SObject withoutInsert() {
            return parent.getObjectWithoutInsert(sObjectType, variant, parameters);
        }
    }

    private class TestRecordGeneratorPriorityComparator implements Comparator {
        public Integer compare(Object object1, Object object2) {
            Decimal priority1 = ((Test_Record_Generator__mdt)object1).Priority__c;
            Decimal priority2 = ((Test_Record_Generator__mdt)object2).Priority__c;
            if(priority1 == null && priority2 == null) {
                return 0;
            } else if(priority1 == null || priority2 == null) {
                return priority1 == null ? 1 : -1;
            } else {
                return (Integer)(priority1 - priority2);
            }
        }
    }

    private static Integer metadataIdNumber = 1;

    private Id getNextMetadataId() {
        return Test_Record_Generator__mdt.SObjectType.getDescribe().getKeyPrefix() + String.valueOf(metadataIdNumber++).leftPad(4, '0') + '0'.repeat(8);
    }

    global void setMetadata(SObject exampleObject, Test_Record_Generator__mdt metadataRecord) {
        metadataRecord.Id = getNextMetadataId();

        List<Test_Record_Generator__mdt> existingMatches = generatorMetadata.getAll(metadataRecord);
        if(existingMatches.isEmpty()) {
            generatorMetadata.put(metadataRecord);
        } else {
            existingMatches.add(metadataRecord);
            Lists.sort(existingMatches, new TestRecordGeneratorPriorityComparator());
        }

        Map<String, Object> populatedFields = exampleObject.getPopulatedFieldsAsMap();
        List<Test_Record_Generator_Field__mdt> newFields = new List<Test_Record_Generator_Field__mdt>();
        for(String field : populatedFields.keySet()) {
            newFields.add(new Test_Record_Generator_Field__mdt(
                    Test_Record_Generator__c = metadataRecord.Id,
                    Field__c = field,
                    Value__c = String.valueOf(populatedFields.get(field))));
        }
        generatorFieldMetadata.putAll(newFields);
    }
}